defmodule Procession.Simulation.MovementPredictabilityExperiment do
  @moduledoc """
  Compares consequence-sensitive plasticity under two source-motion regimes.

  `:teleport` reverses the resource gradient abruptly. `:drift` moves the source
  one position at a time, preserving short-term continuity that an entity can
  exploit without being given the source position or a correct action.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.FlowNetwork

  @actions [:left, :right, :remain]
  @variants [:reactive, :adaptive]
  @modes [:teleport, :drift]

  defmodule State do
    @moduledoc false
    defstruct variant: :adaptive,
              mode: :drift,
              seed: 1,
              tick: 0,
              store: 0.55,
              integrity: 1.0,
              position: 5,
              persisted: true,
              field: nil,
              total_intake: 0.0,
              useful_actions: 0,
              obsolete_actions: 0,
              history: []
  end

  defmodule Summary do
    @moduledoc false
    defstruct [:mode, :variant, :median_lifetime, :survived, :survival_rate,
               :median_intake, :median_useful, :median_obsolete]
  end

  def run(opts \\ []) do
    mode = Keyword.get(opts, :mode, :drift)
    variant = Keyword.get(opts, :variant, :adaptive)
    unless mode in @modes, do: raise(ArgumentError, "unknown mode: #{inspect(mode)}")
    unless variant in @variants, do: raise(ArgumentError, "unknown variant: #{inspect(variant)}")

    ticks = Keyword.get(opts, :ticks, 240)
    initial = %State{
      mode: mode,
      variant: variant,
      seed: Keyword.get(opts, :seed, 1),
      store: Keyword.get(opts, :initial_store, 0.55),
      integrity: Keyword.get(opts, :initial_integrity, 1.0),
      position: Keyword.get(opts, :initial_position, 5),
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
    ticks = Keyword.get(opts, :ticks, 240)
    seeds = Keyword.get(opts, :seeds, Enum.to_list(1..100))

    for mode <- @modes, variant <- @variants, into: %{} do
      states = Enum.map(seeds, &run(Keyword.merge(opts, mode: mode, variant: variant, seed: &1, ticks: ticks)))
      lifetimes = Enum.map(states, & &1.tick)
      survived = Enum.count(lifetimes, &(&1 >= ticks))

      {{mode, variant},
       %Summary{
         mode: mode,
         variant: variant,
         median_lifetime: median(lifetimes),
         survived: survived,
         survival_rate: survived / max(1, length(states)),
         median_intake: states |> Enum.map(& &1.total_intake) |> median(),
         median_useful: states |> Enum.map(& &1.useful_actions) |> median(),
         median_obsolete: states |> Enum.map(& &1.obsolete_actions) |> median()
       }}
    end
  end

  def report(results) when is_map(results) do
    Enum.map_join(@modes, "\n", fn mode ->
      rows = Enum.map_join(@variants, "\n", fn variant ->
        s = Map.fetch!(results, {mode, variant})
        "  #{variant}: life=#{fmt(s.median_lifetime)} survived=#{s.survived} " <>
          "intake=#{fmt(s.median_intake)} useful=#{fmt(s.median_useful)} obsolete=#{fmt(s.median_obsolete)}"
      end)
      "#{mode}:\n#{rows}"
    end)
  end

  def missing_couplings do
    [:explicit_self_motion_sensing, :distance_sensing, :temporal_prediction,
     :multiple_resources, :obstacles, :other_entities, :development]
  end

  defp new_field do
    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action)
    end)
  end

  defp advance(state, tick, opts) do
    source = source_position(state.mode, tick, opts)
    before = intake(state.position, source, opts)
    available = min(1.1, state.store + before)
    requirement = Keyword.get(opts, :maintenance_requirement, 0.082)
    spend = min(available, Keyword.get(opts, :max_throughput, 0.16))

    result = FlowNetwork.run(maintenance_network(), %{available: spend}, [:maintenance],
      threshold: 0.0001, attenuation: 0.995, permeability_scale: 0.05, max_ticks: 2)

    maintenance = Map.get(result.transferred, :maintenance, 0.0)
    after_maintenance = max(0.0, available - maintenance - result.unresolved)
    strain = max(0.0, requirement - maintenance) / requirement
    {action, activation} = choose_action(state, strain, tick)
    next_position = move(state.position, action, opts)
    after_intake = intake(next_position, source, opts)
    delta = after_intake - before
    cost = if action == :remain, do: 0.002, else: Keyword.get(opts, :move_cost, 0.008)
    funded = min(after_maintenance, cost)

    next_field = update_field(state, action, activation, delta, opts)
    integrity = update_integrity(state.integrity, maintenance, requirement, cost - funded, opts)
    persisted = integrity > Keyword.get(opts, :failure_threshold, 0.10)

    %{state |
      tick: tick,
      store: max(0.0, after_maintenance - funded),
      integrity: integrity,
      position: next_position,
      persisted: persisted,
      field: next_field,
      total_intake: state.total_intake + before,
      useful_actions: state.useful_actions + if(delta > 1.0e-9, do: 1, else: 0),
      obsolete_actions: state.obsolete_actions + if(delta < -1.0e-9, do: 1, else: 0),
      history: [%{tick: tick, source: source, action: action, delta: delta, position: next_position} | state.history]
    }
  end

  defp maintenance_network do
    FlowNetwork.new() |> FlowNetwork.add_transition(:available, :maintenance, resistance: 0.18)
  end

  defp choose_action(state, strain, tick) when strain < 0.01, do: {:remain, nil}
  defp choose_action(state, strain, tick) do
    result = PermeableFlow.run(state.field, %{strain: max(strain, 0.06)}, @actions,
      threshold: 0.0001, attenuation: 0.995, permeability_scale: 0.32, max_ticks: 2)
    {weighted_action(result.exit_activation, {state.seed, tick}), result}
  end

  defp weighted_action(weights, seed) do
    entries = Enum.map(@actions, &{&1, max(0.0, Map.get(weights, &1, 0.0))})
    total = Enum.reduce(entries, 0.0, fn {_a, w}, acc -> acc + w end)
    if total <= 0.0, do: :remain, else: pick(entries, unit(seed) * total)
  end

  defp pick([{action, _}], _), do: action
  defp pick([{action, weight} | _], threshold) when threshold <= weight, do: action
  defp pick([{_, weight} | rest], threshold), do: pick(rest, threshold - weight)

  defp update_field(%State{variant: :reactive, field: field}, _action, _result, _delta, _opts), do: field
  defp update_field(%State{field: field}, _action, nil, _delta, _opts), do: field
  defp update_field(%State{variant: :adaptive, field: field}, action, result, delta, opts) do
    cond do
      delta > 1.0e-9 ->
        selected = Map.take(result.flows, [{:strain, action}])
        FlowLearning.apply(field, selected, deposit: Keyword.get(opts, :learning_deposit, 0.12),
          decay_slowing: 0.10, decay_scale: 0.0)
      delta < -1.0e-9 ->
        CognitiveField.disturb_terminal(field, [:strain, action],
          magnitude: Keyword.get(opts, :contradiction_magnitude, 0.30), fraction: 1.0)
      true -> field
    end
  end

  defp source_position(:teleport, tick, opts) do
    max = Keyword.get(opts, :world_max, 10)
    interval = Keyword.get(opts, :source_interval, 40)
    if rem(div(tick - 1, interval), 2) == 0, do: 0, else: max
  end

  defp source_position(:drift, tick, opts) do
    max = Keyword.get(opts, :world_max, 10)
    step_interval = Keyword.get(opts, :drift_step_interval, 4)
    phase = div(tick - 1, step_interval)
    cycle = max * 2
    offset = rem(phase, cycle)
    if offset <= max, do: offset, else: cycle - offset
  end

  defp intake(position, source, opts) do
    peak = Keyword.get(opts, :source_intake, 0.22)
    falloff = Keyword.get(opts, :intake_falloff, 0.032)
    max(0.0, peak - falloff * abs(position - source))
  end

  defp move(position, :left, _opts), do: max(0, position - 1)
  defp move(position, :right, opts), do: min(Keyword.get(opts, :world_max, 10), position + 1)
  defp move(position, :remain, _opts), do: position

  defp update_integrity(integrity, maintenance, requirement, shortfall, opts) do
    next = if maintenance >= requirement,
      do: min(1.0, integrity + Keyword.get(opts, :recovery_rate, 0.004)),
      else: max(0.0, integrity - Keyword.get(opts, :integrity_loss, 0.028) * ((requirement - maintenance) / requirement))
    max(0.0, next - shortfall * 0.8)
  end

  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    n = length(sorted)
    i = div(n, 2)
    if rem(n, 2) == 1, do: Enum.at(sorted, i) * 1.0,
      else: (Enum.at(sorted, i - 1) + Enum.at(sorted, i)) / 2
  end

  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
