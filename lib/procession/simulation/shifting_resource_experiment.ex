defmodule Procession.Simulation.ShiftingResourceExperiment do
  @moduledoc """
  Tests whether consequence-sensitive plasticity helps a self-maintaining pattern
  track a replenishment source whose location changes over time.

  The world contains no hunger, survival goal, planner, or correct-action lookup.
  Maintenance shortfall activates competing exits. Their effects change position,
  and the resulting change in intake determines how selected routes change.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.FlowNetwork

  @variants [:uncoupled, :reactive, :maladaptive, :adaptive]
  @actions [:left, :right, :remain]

  defmodule State do
    @moduledoc false
    defstruct variant: :adaptive,
              seed: 1,
              tick: 0,
              store: 0.55,
              integrity: 1.0,
              position: 5,
              source_position: 0,
              persisted: true,
              field: nil,
              total_intake: 0.0,
              successful_adjustments: 0,
              obsolete_actions: 0,
              source_changes_survived: 0,
              history: []
  end

  defmodule TrialSummary do
    @moduledoc false
    @enforce_keys [
      :variant,
      :lifetimes,
      :median_lifetime,
      :survived,
      :survival_rate,
      :median_intake,
      :median_adjustments,
      :median_obsolete_actions,
      :median_changes_survived
    ]
    defstruct @enforce_keys
  end

  defmodule Comparison do
    @moduledoc false
    @enforce_keys [:ticks, :seeds, :summaries]
    defstruct @enforce_keys
  end

  def variants, do: @variants

  def new_field do
    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action)
    end)
  end

  def run(opts \\ []) do
    variant = Keyword.get(opts, :variant, :adaptive)
    unless variant in @variants, do: raise(ArgumentError, "unknown variant: #{inspect(variant)}")

    ticks = Keyword.get(opts, :ticks, 180)

    initial = %State{
      variant: variant,
      seed: Keyword.get(opts, :seed, 1),
      store: Keyword.get(opts, :initial_store, 0.55),
      integrity: Keyword.get(opts, :initial_integrity, 1.0),
      position: Keyword.get(opts, :initial_position, 5),
      source_position: source_position(1, opts),
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

  def compare(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 180)
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..80))

    summaries =
      Map.new(@variants, fn variant ->
        states =
          Enum.map(seeds, fn seed ->
            run(Keyword.merge(opts, variant: variant, seed: seed, ticks: ticks))
          end)

        lifetimes = Enum.map(states, & &1.tick)
        survived = Enum.count(lifetimes, &(&1 >= ticks))

        {variant,
         %TrialSummary{
           variant: variant,
           lifetimes: lifetimes,
           median_lifetime: median(lifetimes),
           survived: survived,
           survival_rate: survived / max(1, length(states)),
           median_intake: states |> Enum.map(& &1.total_intake) |> median(),
           median_adjustments: states |> Enum.map(& &1.successful_adjustments) |> median(),
           median_obsolete_actions: states |> Enum.map(& &1.obsolete_actions) |> median(),
           median_changes_survived: states |> Enum.map(& &1.source_changes_survived) |> median()
         }}
      end)

    %Comparison{ticks: ticks, seeds: seeds, summaries: summaries}
  end

  def report(%Comparison{} = comparison) do
    rows =
      Enum.map_join(@variants, "\n", fn variant ->
        summary = Map.fetch!(comparison.summaries, variant)

        "#{variant}: median_life=#{format(summary.median_lifetime)} " <>
          "survived=#{summary.survived}/#{length(comparison.seeds)} " <>
          "intake=#{format(summary.median_intake)} " <>
          "adjustments=#{format(summary.median_adjustments)} " <>
          "obsolete=#{format(summary.median_obsolete_actions)} " <>
          "changes=#{format(summary.median_changes_survived)}"
      end)

    "ticks per trial: #{comparison.ticks}\n#{rows}"
  end

  def report(%State{} = state) do
    """
    variant: #{state.variant}
    ticks completed: #{state.tick}
    pattern persisted: #{state.persisted}
    position: #{state.position}
    source position: #{state.source_position}
    integrity: #{format(state.integrity)}
    remaining store: #{format(state.store)}
    total intake: #{format(state.total_intake)}
    successful adjustments: #{state.successful_adjustments}
    obsolete actions: #{state.obsolete_actions}
    source changes survived: #{state.source_changes_survived}
    left resistance: #{format(CognitiveField.resistance(state.field, :strain, :left))}
    right resistance: #{format(CognitiveField.resistance(state.field, :strain, :right))}
    remain resistance: #{format(CognitiveField.resistance(state.field, :strain, :remain))}
    """
    |> String.trim()
  end

  def missing_couplings do
    [
      :real_physiology,
      :multiple_resources,
      :continuous_space,
      :distance_sensing,
      :obstacles,
      :damage_types,
      :repair,
      :other_entities,
      :development,
      :semantic_cognition
    ]
  end

  defp advance(state, tick, opts) do
    source = source_position(tick, opts)
    source_changed = source != state.source_position
    intake_before = environmental_intake(state.position, source, opts)
    available = min(1.1, state.store + intake_before)
    requirement = Keyword.get(opts, :maintenance_requirement, 0.082)
    spend_limit = min(available, Keyword.get(opts, :max_throughput, 0.16))

    maintenance_result =
      FlowNetwork.run(maintenance_network(), %{available: spend_limit}, [:maintenance],
        threshold: 0.0001,
        attenuation: 0.995,
        permeability_scale: 0.05,
        max_ticks: 2
      )

    maintenance = Map.get(maintenance_result.transferred, :maintenance, 0.0)
    spent = maintenance + maintenance_result.unresolved
    after_maintenance = max(0.0, available - spent)
    strain = max(0.0, requirement - maintenance) / requirement

    {action, activation_result} = choose_action(state, strain, tick, opts)
    next_position = apply_action(state.position, action, opts)
    intake_after = environmental_intake(next_position, source, opts)
    delta = intake_after - intake_before
    action_cost = action_cost(action, opts)
    funded_cost = min(after_maintenance, action_cost)
    next_field = update_field(state, action, activation_result, delta, opts)

    integrity =
      state.integrity
      |> apply_maintenance(maintenance, requirement, opts)
      |> apply_action_shortfall(action_cost - funded_cost, opts)

    persisted = integrity > Keyword.get(opts, :failure_threshold, 0.10)
    improved = delta > 1.0e-9
    worsened = delta < -1.0e-9

    snapshot = %{
      tick: tick,
      source: source,
      source_changed: source_changed,
      position: next_position,
      strain: strain,
      action: action,
      intake_before: intake_before,
      intake_after: intake_after,
      improved: improved,
      worsened: worsened,
      integrity: integrity,
      persisted: persisted
    }

    %State{
      state
      | tick: tick,
        store: max(0.0, after_maintenance - funded_cost),
        integrity: integrity,
        position: next_position,
        source_position: source,
        persisted: persisted,
        field: next_field,
        total_intake: state.total_intake + intake_before,
        successful_adjustments:
          state.successful_adjustments + if(improved, do: 1, else: 0),
        obsolete_actions: state.obsolete_actions + if(worsened, do: 1, else: 0),
        source_changes_survived:
          state.source_changes_survived + if(source_changed and persisted, do: 1, else: 0),
        history: [snapshot | state.history]
    }
  end

  defp maintenance_network do
    FlowNetwork.new()
    |> FlowNetwork.add_transition(:available, :maintenance, resistance: 0.18)
  end

  defp choose_action(%State{variant: :uncoupled}, _strain, _tick, _opts),
    do: {:remain, nil}

  defp choose_action(state, strain, tick, opts) do
    if strain < Keyword.get(opts, :minimum_strain, 0.01) do
      {:remain, nil}
    else
      result =
        PermeableFlow.run(state.field, %{strain: max(strain, 0.06)}, @actions,
          threshold: 0.0001,
          attenuation: 0.995,
          permeability_scale: Keyword.get(opts, :activation_permeability_scale, 0.32),
          max_ticks: 2
        )

      {weighted_action(result.exit_activation, {state.seed, tick}), result}
    end
  end

  defp weighted_action(exit_activation, seed) do
    weights = Enum.map(@actions, &{&1, max(0.0, Map.get(exit_activation, &1, 0.0))})
    total = Enum.reduce(weights, 0.0, fn {_action, weight}, acc -> acc + weight end)

    if total <= 0.0,
      do: :remain,
      else: pick(weights, deterministic_unit(seed) * total)
  end

  defp pick([{action, _weight}], _threshold), do: action
  defp pick([{action, weight} | _rest], threshold) when threshold <= weight, do: action
  defp pick([{_action, weight} | rest], threshold), do: pick(rest, threshold - weight)

  defp update_field(%State{variant: variant, field: field}, _action, _result, _delta, _opts)
       when variant in [:uncoupled, :reactive],
       do: field

  defp update_field(%State{variant: :maladaptive, field: field}, action, result, _delta, opts)
       when not is_nil(result),
       do: reinforce_selected(field, action, result, opts)

  defp update_field(%State{variant: :adaptive, field: field}, action, result, delta, opts)
       when not is_nil(result) do
    cond do
      delta > 1.0e-9 ->
        reinforce_selected(field, action, result, opts)

      delta < -1.0e-9 ->
        CognitiveField.disturb_terminal(field, [:strain, action],
          magnitude: Keyword.get(opts, :contradiction_magnitude, 0.14),
          fraction: 1.0
        )

      true ->
        field
    end
  end

  defp update_field(%State{field: field}, _action, _result, _delta, _opts), do: field

  defp reinforce_selected(field, action, result, opts) do
    selected =
      Enum.reduce(result.flows, %{}, fn
        {{_from, ^action} = edge, magnitude}, acc -> Map.put(acc, edge, magnitude)
        {_edge, _magnitude}, acc -> acc
      end)

    FlowLearning.apply(field, selected,
      deposit: Keyword.get(opts, :learning_deposit, 0.16),
      decay_slowing: Keyword.get(opts, :learning_decay_slowing, 0.12),
      decay_scale: 0.0
    )
  end

  defp source_position(tick, opts) do
    interval = Keyword.get(opts, :source_interval, 30)
    far = Keyword.get(opts, :world_max, 10)
    if rem(div(max(tick - 1, 0), interval), 2) == 0, do: 0, else: far
  end

  defp environmental_intake(position, source, opts) do
    peak = Keyword.get(opts, :source_intake, 0.20)
    falloff = Keyword.get(opts, :intake_falloff, 0.025)
    max(0.0, peak - falloff * abs(position - source))
  end

  defp apply_action(position, :left, _opts), do: max(0, position - 1)

  defp apply_action(position, :right, opts),
    do: min(Keyword.get(opts, :world_max, 10), position + 1)

  defp apply_action(position, :remain, _opts), do: position

  defp action_cost(:remain, opts), do: Keyword.get(opts, :remain_cost, 0.003)
  defp action_cost(_move, opts), do: Keyword.get(opts, :move_cost, 0.018)

  defp apply_maintenance(integrity, maintenance, requirement, opts) do
    if maintenance >= requirement do
      min(1.0, integrity + Keyword.get(opts, :recovery_rate, 0.003))
    else
      max(
        0.0,
        integrity -
          Keyword.get(opts, :integrity_loss, 0.05) *
            ((requirement - maintenance) / requirement)
      )
    end
  end

  defp apply_action_shortfall(integrity, shortfall, opts) when shortfall > 0.0,
    do: max(0.0, integrity - shortfall * Keyword.get(opts, :action_shortfall_scale, 0.8))

  defp apply_action_shortfall(integrity, _shortfall, _opts), do: integrity

  defp deterministic_unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000

  defp median([]), do: 0.0

  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)

    if rem(length(sorted), 2) == 1,
      do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end

  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
