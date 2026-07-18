defmodule Procession.Simulation.CognitiveField.PermeableFlow do
  @moduledoc """
  Cognitive-field wrapper over the domain-neutral local flow network.

  Absolute transition resistance controls how much activation survives each
  edge, while relative resistance controls how surviving activation divides
  among alternatives.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.FlowNetwork

  defmodule Result do
    @moduledoc false
    @type t :: %__MODULE__{
            initial_activation: map(),
            exit_activation: map(),
            remaining_activation: map(),
            flows: map(),
            dissipated: float(),
            history: [map()],
            ticks: non_neg_integer()
          }
    @enforce_keys [:initial_activation, :exit_activation, :remaining_activation, :flows, :dissipated, :history, :ticks]
    defstruct [:initial_activation, :exit_activation, :remaining_activation, :flows, :dissipated, :history, :ticks]
  end

  @spec run(CognitiveField.t(), map(), [term()] | MapSet.t(), keyword()) :: Result.t()
  def run(%CognitiveField{} = field, activation, exits, opts \\ []) do
    generic =
      Enum.reduce(field.transitions, FlowNetwork.new(), fn {{from, to}, _transition}, network ->
        FlowNetwork.add_transition(network, from, to,
          resistance: CognitiveField.resistance(field, from, to)
        )
      end)

    result = FlowNetwork.run(generic, activation, exits, opts)

    %Result{
      initial_activation: result.entered,
      exit_activation: result.transferred,
      remaining_activation: result.retained,
      flows: result.flows,
      dissipated: result.unresolved,
      history: result.history,
      ticks: result.ticks
    }
  end

  @spec total_initial(Result.t()) :: float()
  def total_initial(result), do: sum_map(result.initial_activation)

  @spec total_exited(Result.t()) :: float()
  def total_exited(result), do: sum_map(result.exit_activation)

  @spec total_remaining(Result.t()) :: float()
  def total_remaining(result), do: sum_map(result.remaining_activation)

  @spec conserved?(Result.t(), float()) :: boolean()
  def conserved?(result, tolerance \\ 1.0e-9) do
    abs(total_initial(result) - total_exited(result) - total_remaining(result) - result.dissipated) <= tolerance
  end

  @spec furthest_reached(Result.t(), [term()]) :: term() | nil
  def furthest_reached(result, ordered_nodes) do
    reached =
      result.history
      |> Enum.flat_map(&Map.keys/1)
      |> MapSet.new()

    ordered_nodes
    |> Enum.filter(&MapSet.member?(reached, &1))
    |> List.last()
  end

  defp sum_map(map), do: Enum.reduce(map, 0.0, fn {_key, value}, acc -> acc + value end)
end
