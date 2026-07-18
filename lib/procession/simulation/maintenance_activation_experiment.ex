defmodule Procession.Simulation.MaintenanceActivationExperiment do
  @moduledoc """
  Couples a finite self-maintaining circulation to a small adaptive activation
  field and a one-dimensional replenishment environment.

  The experiment compares three variants:

  - `:uncoupled` never exposes maintenance strain to the activation field.
  - `:reactive` exposes strain, but leaves the field topology unchanged.
  - `:adaptive` exposes strain and changes only the selected route after that
    action improves environmental intake.

  Present couplings:

  - finite internal store and maintenance-dependent persistence
  - maintenance shortfall converted into activation magnitude
  - competing action interfaces
  - action cost and spatial consequence
  - position-dependent external intake
  - optional experience-dependent transition change

  Missing couplings include real physiology, multiple resource channels,
  continuous mechanics, rich sensing, damage types, repair, other entities,
  reproduction, development, and semantic cognition. The experiment therefore
  tests prerequisites for survival-like behavior rather than claiming to model
  hunger, intention, or a survival goal.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.FlowNetwork

  @variants [:uncoupled, :reactive, :adaptive]

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            variant: atom(),
            seed: integer(),
            tick: non_neg_integer(),
            store: float(),
            integrity: float(),
            position: non_neg_integer(),
            persisted: boolean(),
            field: CognitiveField.t(),
            approaches: non_neg_integer(),
            remains: non_neg_integer(),
            total_intake: float(),
            history: [map()]
          }

    defstruct variant: :uncoupled,
              seed: 0,
              tick: 0,
              store: 0.52,
              integrity: 1.0,
              position: 6,
              persisted: true,
              field: nil,
              approaches: 0,
              remains: 0,
              total_intake: 0.0,
              history: []
  end

  defmodule TrialSummary do
    @moduledoc false
    @enforce_keys [:variant, :lifetimes, :median_lifetime, :survived, :survival_rate]
    defstruct [:variant, :lifetimes, :median_lifetime, :survived, :survival_rate]
  end

  defmodule Comparison do
    @moduledoc false
    @enforce_keys [:ticks, :seeds, :summaries]
    defstruct [:ticks, :seeds, :summaries]
  end

  @spec variants() :: [atom()]
  def variants, do: @variants

  @spec new_field() :: CognitiveField.t()
  def new_field do
    CognitiveField.new()
    |> CognitiveField.add_transition(:strain, :approach)
    |> CognitiveField.add_transition(:strain, :remain)
  end

  @spec run(keyword()) :: State.t()
  def run(opts \\ []) do
    variant = Keyword.get(opts, :variant, :adaptive)

    unless variant in @variants do
      raise ArgumentError, "unknown variant: #{inspect(variant)}"
    end

    ticks = Keyword.get(opts, :ticks, 120)

    initial = %State{
      variant: variant,
      seed: Keyword.get(opts, :seed, 1),
      store: Keyword.get(opts, :initial_store, 0.52),
      integrity: Keyword.get(opts, :initial_integrity, 1.0),
      position: Keyword.get(opts, :initial_position, 6),
      field: new_field()
    }

    if ticks <= 0 do
      initial
    else
      Enum.reduce_while(1..ticks, initial, fn tick, state ->
        next = advance(state, tick, opts)
        if next.persisted, do: {:cont, next}, else: {:halt, next}
      end)
    end
  end

  @spec compare(keyword()) :: Comparison.t()
  def compare(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 120)
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..60))

    summaries =
      Map.new(@variants, fn variant ->
        lifetimes =
          Enum.map(seeds, fn seed ->
            run(Keyword.merge(opts, variant: variant, seed: seed, ticks: ticks)).tick
          end)

        survived = Enum.count(lifetimes, &(&1 >= ticks))

        {variant,
         %TrialSummary{
           variant: variant,
           lifetimes: lifetimes,
           median_lifetime: median(lifetimes),
           survived: survived,
           survival_rate: survived / max(1, length(lifetimes))
         }}
      end)

    %Comparison{ticks: ticks, seeds: seeds, summaries: summaries}
  end

  @spec report(State.t() | Comparison.t()) :: String.t()
  def report(%State{} = state) do
    """
    variant: #{state.variant}
    ticks completed: #{state.tick}
    pattern persisted: #{state.persisted}
    position from source: #{state.position}
    remaining store: #{format(state.store)}
    integrity: #{format(state.integrity)}
    total external intake: #{format(state.total_intake)}
    approach actions: #{state.approaches}
    remain actions: #{state.remains}
    approach resistance: #{format(CognitiveField.resistance(state.field, :strain, :approach))}
    remain resistance: #{format(CognitiveField.resistance(state.field, :strain, :remain))}
    """
    |> String.trim()
  end

  def report(%Comparison{} = comparison) do
    rows =
      Enum.map_join(@variants, "\n", fn variant ->
        summary = Map.fetch!(comparison.summaries, variant)

        "#{variant}: median=#{format(summary.median_lifetime)} " <>
          "survived=#{summary.survived}/#{length(comparison.seeds)} " <>
          "rate=#{format(summary.survival_rate)}"
      end)

    "ticks per trial: #{comparison.ticks}\n#{rows}"
  end

  @spec missing_couplings() :: [atom()]
  def missing_couplings do
    [
      :real_physiology,
      :multiple_resources,
      :continuous_mechanics,
      :rich_sensing,
      :damage_types,
      :repair,
      :other_entities,
      :reproduction,
      :development,
      :semantic_cognition
    ]
  end

  defp advance(state, tick, opts) do
    intake_before = environmental_intake(state.position, opts)
    available = min(1.2, state.store + intake_before)
    requirement = Keyword.get(opts, :maintenance_requirement, 0.075)
    spend_limit = min(available, Keyword.get(opts, :max_throughput, 0.16))

    maintenance_result =
      FlowNetwork.run(maintenance_network(), %{available: spend_limit}, [:maintenance],
        threshold: 0.0001,
        attenuation: 0.995,
        permeability_scale: 0.05,
        max_ticks: 2
      )

    maintenance = Map.get(maintenance_result.transferred, :maintenance, 0.0)
    maintenance_spent = maintenance + maintenance_result.unresolved
    store_after_maintenance = max(0.0, available - maintenance_spent)
    strain = max(0.0, requirement - maintenance) / requirement

    {action, activation_result} = choose_action(state, strain, tick, opts)
    action_cost = action_cost(action, opts)
    next_position = apply_action(state.position, action)
    next_intake = environmental_intake(next_position, opts)
    improved_access = next_intake > intake_before + 1.0e-9

    next_field = update_field(state, action, activation_result, improved_access, opts)
    funded_cost = min(store_after_maintenance, action_cost)
    next_store = max(0.0, store_after_maintenance - funded_cost)

    integrity =
      state.integrity
      |> apply_maintenance(maintenance, requirement, opts)
      |> apply_action_shortfall(action_cost - funded_cost, opts)

    persisted = integrity > Keyword.get(opts, :failure_threshold, 0.10)

    snapshot = %{
      tick: tick,
      strain: strain,
      maintenance: maintenance,
      action: action,
      action_cost: action_cost,
      position: next_position,
      intake: intake_before,
      next_intake: next_intake,
      improved_access: improved_access,
      store: next_store,
      integrity: integrity,
      persisted: persisted
    }

    %State{
      state
      | tick: tick,
        store: next_store,
        integrity: integrity,
        position: next_position,
        persisted: persisted,
        field: next_field,
        approaches: state.approaches + if(action == :approach, do: 1, else: 0),
        remains: state.remains + if(action == :remain, do: 1, else: 0),
        total_intake: state.total_intake + intake_before,
        history: [snapshot | state.history]
    }
  end

  defp maintenance_network do
    FlowNetwork.new()
    |> FlowNetwork.add_transition(:available, :maintenance, resistance: 0.18)
  end

  defp choose_action(%State{variant: :uncoupled}, _strain, _tick, _opts), do: {:remain, nil}

  defp choose_action(state, strain, tick, opts) do
    minimum_strain = Keyword.get(opts, :minimum_strain, 0.015)

    if strain < minimum_strain do
      {:remain, nil}
    else
      result =
        PermeableFlow.run(state.field, %{strain: max(strain, 0.05)}, [:approach, :remain],
          threshold: 0.0001,
          attenuation: 0.995,
          permeability_scale: 0.25,
          max_ticks: 2
        )

      {weighted_action(result.exit_activation, {state.seed, tick}), result}
    end
  end

  defp weighted_action(exit_activation, seed) do
    approach = max(0.0, Map.get(exit_activation, :approach, 0.0))
    remain = max(0.0, Map.get(exit_activation, :remain, 0.0))
    total = approach + remain

    cond do
      total <= 0.0 -> :remain
      deterministic_unit(seed) * total < approach -> :approach
      true -> :remain
    end
  end

  defp update_field(%State{variant: :adaptive, field: field}, action, result, true, opts)
       when not is_nil(result) do
    selected_flows =
      Map.new(result.flows, fn
        {{from, ^action} = edge, magnitude} -> {edge, magnitude}
        {_edge, _magnitude} -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    FlowLearning.apply(field, selected_flows,
      deposit: Keyword.get(opts, :learning_deposit, 0.10),
      decay_slowing: Keyword.get(opts, :learning_decay_slowing, 0.10)
    )
  end

  defp update_field(%State{variant: :adaptive, field: field}, _action, _result, false, _opts),
    do: field

  defp update_field(%State{field: field}, _action, _result, _improved_access, _opts), do: field

  defp environmental_intake(position, opts) do
    source = Keyword.get(opts, :source_intake, 0.24)
    falloff = Keyword.get(opts, :intake_falloff, 0.035)
    max(0.0, source - falloff * position)
  end

  defp apply_action(position, :approach), do: max(0, position - 1)
  defp apply_action(position, :remain), do: position

  defp action_cost(:approach, opts), do: Keyword.get(opts, :approach_cost, 0.025)
  defp action_cost(:remain, opts), do: Keyword.get(opts, :remain_cost, 0.004)

  defp apply_maintenance(integrity, maintenance, requirement, opts) do
    if maintenance >= requirement do
      min(1.0, integrity + Keyword.get(opts, :recovery_rate, 0.004))
    else
      loss = Keyword.get(opts, :integrity_loss, 0.045)
      max(0.0, integrity - loss * ((requirement - maintenance) / requirement))
    end
  end

  defp apply_action_shortfall(integrity, shortfall, opts) when shortfall > 0.0 do
    max(0.0, integrity - shortfall * Keyword.get(opts, :action_shortfall_scale, 0.8))
  end

  defp apply_action_shortfall(integrity, _shortfall, _opts), do: integrity

  defp deterministic_unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000

  defp median([]), do: 0.0

  defp median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)

    if rem(count, 2) == 1 do
      Enum.at(sorted, middle) * 1.0
    else
      (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
    end
  end

  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
