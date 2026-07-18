defmodule Procession.Simulation.CognitiveField.EmbodiedExperiment do
  @moduledoc """
  A tiny functional world used to exercise cognitive-field behavior in a closed loop.

  World state produces perception activation, field exits become actions, and the
  world alone decides whether the resulting continuation was coherent.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.FlowLearning
  alias Procession.Simulation.CognitiveField.PermeableFlow
  alias Procession.Simulation.CognitiveField.Transition

  @actions [:seek_shelter, :seek_food, :wait]
  @atomic_signals [:rain, :clear, :hungry, :sated, :shelter_blocked, :shelter_open]
  @contexts for weather <- [:rain, :clear], hunger <- [:hungry, :sated], blocked <- [false, true], do: {:context, weather, hunger, blocked}
  @signals @atomic_signals ++ @contexts

  defmodule World do
    @moduledoc false
    @type t :: %__MODULE__{weather: :rain | :clear, hunger: :hungry | :sated, shelter_blocked: boolean()}
    defstruct weather: :rain, hunger: :sated, shelter_blocked: false
  end

  defmodule Episode do
    @moduledoc false
    @type t :: %__MODULE__{
            index: pos_integer(),
            world: World.t(),
            action: atom(),
            coherent: boolean(),
            exit_activation: map(),
            dissipated: float()
          }
    @enforce_keys [:index, :world, :action, :coherent, :exit_activation, :dissipated]
    defstruct [:index, :world, :action, :coherent, :exit_activation, :dissipated]
  end

  @spec new_field() :: CognitiveField.t()
  def new_field do
    Enum.reduce(@signals, CognitiveField.new(), fn signal, field ->
      Enum.reduce(@actions, field, fn action, acc ->
        CognitiveField.add_transition(acc, signal, action)
      end)
    end)
  end

  @spec run([World.t()], keyword()) :: %{field: CognitiveField.t(), episodes: [Episode.t()]}
  def run(worlds, opts \\ []) when is_list(worlds) do
    initial_field = Keyword.get(opts, :field, new_field())

    {field, episodes} =
      worlds
      |> Enum.with_index(1)
      |> Enum.reduce({initial_field, []}, fn {world, index}, {field, episodes} ->
        {updated, episode} = step(field, world, index, opts)
        {updated, [episode | episodes]}
      end)

    %{field: field, episodes: Enum.reverse(episodes)}
  end

  @spec step(CognitiveField.t(), World.t(), pos_integer(), keyword()) ::
          {CognitiveField.t(), Episode.t()}
  def step(%CognitiveField{} = field, %World{} = world, index, opts \\ []) do
    result =
      PermeableFlow.run(field, perceive(world), @actions,
        threshold: Keyword.get(opts, :threshold, 0.001),
        attenuation: Keyword.get(opts, :attenuation, 0.98),
        permeability_scale: Keyword.get(opts, :permeability_scale, 0.35),
        max_ticks: 2
      )

    action = choose_action(result.exit_activation, index)
    coherent = coherent?(world, action)
    selected_flows = selected_flows(result.flows, action)

    updated =
      if coherent do
        FlowLearning.apply(field, selected_flows,
          deposit: Keyword.get(opts, :deposit, 0.11),
          decay_slowing: 0.08,
          decay_scale: 0.03
        )
      else
        contradict(field, selected_flows, Keyword.get(opts, :contradiction, 0.075))
      end

    episode = %Episode{
      index: index,
      world: world,
      action: action,
      coherent: coherent,
      exit_activation: result.exit_activation,
      dissipated: result.dissipated
    }

    {updated, episode}
  end

  @spec rainy_worlds(pos_integer(), boolean()) :: [World.t()]
  def rainy_worlds(count, blocked \\ false) do
    List.duplicate(%World{weather: :rain, hunger: :sated, shelter_blocked: blocked}, count)
  end

  @spec hungry_worlds(pos_integer()) :: [World.t()]
  def hungry_worlds(count) do
    List.duplicate(%World{weather: :clear, hunger: :hungry, shelter_blocked: false}, count)
  end

  @spec action_counts([Episode.t()]) :: map()
  def action_counts(episodes), do: Enum.frequencies_by(episodes, & &1.action)

  @spec success_rate([Episode.t()]) :: float()
  def success_rate([]), do: 0.0
  def success_rate(episodes), do: Enum.count(episodes, & &1.coherent) / length(episodes)

  @spec report([Episode.t()], pos_integer()) :: String.t()
  def report(episodes, window \\ 10) do
    first = Enum.take(episodes, window)
    last = Enum.take(episodes, -window)

    """
    Episodes 1-#{length(first)}
    actions: #{inspect(action_counts(first))}
    coherent: #{format_rate(success_rate(first))}

    Final #{length(last)} episodes
    actions: #{inspect(action_counts(last))}
    coherent: #{format_rate(success_rate(last))}
    """
    |> String.trim()
  end

  defp perceive(%World{} = world) do
    blocked = if(world.shelter_blocked, do: :shelter_blocked, else: :shelter_open)
    context = {:context, world.weather, world.hunger, world.shelter_blocked}

    %{
      world.weather => 0.20,
      world.hunger => 0.20,
      blocked => 0.20,
      context => 0.80
    }
  end

  defp choose_action(exit_activation, seed) do
    candidates = Enum.map(@actions, fn action -> {action, Map.get(exit_activation, action, 0.0)} end)
    magnitudes = Enum.map(candidates, &elem(&1, 1))

    if Enum.max(magnitudes) - Enum.min(magnitudes) < 1.0e-9 do
      Enum.at(@actions, rem(seed - 1, length(@actions)))
    else
      candidates
      |> Enum.sort_by(fn {action, magnitude} -> {-magnitude, :erlang.phash2({seed, action})} end)
      |> hd()
      |> elem(0)
    end
  end

  defp coherent?(%World{weather: :rain, shelter_blocked: false}, :seek_shelter), do: true
  defp coherent?(%World{hunger: :hungry, weather: :clear}, :seek_food), do: true
  defp coherent?(%World{weather: :rain, shelter_blocked: true}, :wait), do: true
  defp coherent?(_world, _action), do: false

  defp selected_flows(flows, action) do
    flows
    |> Enum.flat_map(fn
      {{_from, ^action} = edge, magnitude} -> [{edge, magnitude}]
      {_edge, _magnitude} -> []
    end)
    |> Map.new()
  end

  defp contradict(field, flows, magnitude) do
    maximum = flows |> Map.values() |> Enum.max(fn -> 0.0 end)

    transitions =
      Map.new(field.transitions, fn {edge, transition} ->
        flow = Map.get(flows, edge, 0.0)
        share = if maximum > 0.0, do: flow / maximum, else: 0.0

        updated =
          if share > 0.0 do
            %Transition{transition | residue: max(0.0, transition.residue - magnitude * share)}
          else
            transition
          end

        {edge, updated}
      end)

    %{field | transitions: transitions, tick: field.tick + 1}
  end

  defp format_rate(rate), do: :erlang.float_to_binary(rate, decimals: 2)
end
