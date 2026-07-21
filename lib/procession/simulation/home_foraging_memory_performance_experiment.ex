defmodule Procession.Simulation.HomeForagingMemoryPerformanceExperiment do
  @moduledoc """
  Compares actual unsupported learner performance with memory ignored, legacy
  memory guidance, and quality-controlled memory guidance.
  """

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body
  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @conditions [:memory_ignored, :legacy_memory, :quality_memory]
  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}

  @base_opts [
    micro_nodes: 48,
    input_width: 6,
    activity_retention: 0.84,
    edge_retention: 0.9995,
    output_edge_retention: 0.9995,
    consolidation_threshold: 4,
    minimum_compression_gain: 0.0,
    coherence_threshold: 0.025,
    compression_node_threshold: 0.14,
    compression_coverage_threshold: 0.45,
    plasticity_threshold: 0.14,
    output_source_threshold: 0.14,
    output_learning_scale: 0.08,
    output_plasticity_budget: 0.10
  ]

  @quality_opts [
    recursive_quality_gate: true,
    recursive_ancestor_penalty: 1.0,
    recursive_min_residual_members: 2,
    minimum_incremental_compression_gain: 1.0,
    output_source_mode: :rising_residual,
    output_specificity_power: 0.75
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    teaching_ticks = Keyword.get(opts, :teaching_ticks, 2_400)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 2_400)
    seed = Keyword.get(opts, :seed, 7)
    total = teaching_ticks + withdrawal_ticks

    rows = for condition <- @conditions, entity <- 1..population do
      run_one(condition, entity, seed, teaching_ticks, total)
    end

    %{population: population, teaching_ticks: teaching_ticks,
      withdrawal_ticks: withdrawal_ticks, rows: rows, summary: summarize(rows)}
  end

  def report(result) do
    lines = Enum.map(@conditions, fn condition ->
      s = result.summary[condition]
      "#{condition}: survived=#{s.survived}/#{result.population} " <>
        "cycles=#{fmt(s.cycles)} consumers=#{s.consumers}/#{result.population} " <>
        "first_cycle=#{fmt(s.first_cycle)} correct=#{fmt(s.correct)} " <>
        "move=#{fmt(s.move_rate)} recovery=#{fmt(s.recovery)} death=#{fmt(s.death)}"
    end)

    Enum.join([
      "Closed-loop emergent-motor memory performance",
      "matched teaching and withdrawal; behavioral outcomes only",
      "teaching=#{result.teaching_ticks} withdrawal=#{result.withdrawal_ticks}" | lines
    ], "\n")
  end

  defp run_one(condition, entity, seed, teaching_ticks, total) do
    state = %{body: Body.new(), field: Field.new(field_opts(condition, seed, entity)),
      position: @home, carrying: false, vitality: 0.995, warmth: 1.0,
      last_pattern: nil, last_outcome: :none, records: [], cycles: 0}

    final = Enum.reduce_while(1..total, state, fn tick, state ->
      teaching? = tick <= teaching_ticks
      opts = field_opts(condition, seed, entity)
      field = Field.sense(state.field, sensory_features(state), opts)
      desired = physical_goal(state)
      pattern = select_pattern(condition, field, state.body, tick, seed, entity, teaching_ticks, opts)

      {natural_body, natural} = Body.attempt(state.body, pattern, state.position, tick,
        seed: seed + entity * 1_003, bounds: @bounds)

      {body, outcome, position, assisted?} =
        apply_support(state.body, natural_body, natural, state.position, pattern, desired, teaching?)

      {carrying, intake, event} = interact(state.carrying, position, outcome)
      field = Field.record_output(field, pattern, local_coherence(outcome, event), opts)
      warmth = if position == @home, do: min(1.0, state.warmth + 0.015),
        else: max(0.0, state.warmth - 0.00030)
      effort = if assisted?, do: 0.00004, else: 0.00020
      vitality = max(0.0, min(1.0, state.vitality - 0.00014 - effort + intake))
      correct? = pattern_effect_matches?(body, pattern, desired)
      cycle? = event == :food_consumed and not teaching?

      record = %{tick: tick, teaching?: teaching?, correct?: correct?,
        displaced?: outcome.displaced?, event: event, vitality: vitality}
      next = %{state | body: body, field: field, position: position, carrying: carrying,
        vitality: vitality, warmth: warmth, last_pattern: pattern,
        last_outcome: outcome.consequence, records: [record | state.records],
        cycles: state.cycles + if(cycle?, do: 1, else: 0)}

      if vitality > 0.0 and warmth > 0.0, do: {:cont, next}, else: {:halt, next}
    end)

    records = Enum.reverse(final.records)
    withdrawal = Enum.reject(records, & &1.teaching?)
    first_cycle = Enum.find(withdrawal, &(&1.event == :food_consumed))

    %{condition: condition, survived: length(records) == total, death: length(records),
      cycles: final.cycles, consumed?: final.cycles > 0,
      first_cycle: if(first_cycle, do: first_cycle.tick - teaching_ticks, else: nil),
      correct: fraction(withdrawal, & &1.correct?),
      move_rate: fraction(withdrawal, & &1.displaced?),
      recovery: recovery_rate(withdrawal)}
  end

  defp select_pattern(:memory_ignored, _field, body, tick, seed, entity, _teaching, _opts),
    do: Body.choose_pattern(body, tick, seed + entity * 149)

  defp select_pattern(condition, field, body, tick, seed, entity, teaching_ticks, opts)
       when condition in [:legacy_memory, :quality_memory] do
    patterns = Body.patterns()
    scores = Field.output_scores(field, patterns, opts)
    exploration = if tick <= teaching_ticks, do: 0.30, else: 0.06

    patterns
    |> Enum.map(fn pattern ->
      noise = :erlang.phash2({:performance_select, seed, entity, tick, pattern}, 10_000) / 10_000
      {pattern, Map.get(scores, pattern, 0.0) * (1.0 - exploration) + noise * exploration}
    end)
    |> Enum.max_by(fn {pattern, score} -> {score, pattern} end)
    |> elem(0)
  end

  defp apply_support(_before, natural_body, natural, position, _pattern, _desired, false),
    do: {natural_body, natural, Body.apply_displacement(position, natural), false}

  defp apply_support(before, _natural_body, natural, position, pattern, :contact, true) do
    body = Body.supported_stability(before, pattern, 1.0)
    outcome = %{natural | direction: :none, displaced?: false, blocked?: false,
      coordination: Map.fetch!(body.coordination, pattern), consequence: :supported_stability}
    {body, outcome, position, true}
  end

  defp apply_support(before, _natural_body, natural, position, pattern, direction, true) do
    body = Body.supported_attempt(before, pattern, direction, 1.0)
    outcome = %{natural | direction: direction, displaced?: true, blocked?: false,
      coordination: Map.fetch!(body.coordination, pattern), consequence: :supported_displacement}
    {body, outcome, move(position, direction), true}
  end

  defp sensory_features(state), do: [
    {:position, state.position}, {:carrying, state.carrying},
    {:warmth, band(state.warmth)}, {:vitality, band(state.vitality)},
    {:last_pattern, state.last_pattern}, {:last_outcome, state.last_outcome},
    {:food_contact, state.position == @food}, {:home_contact, state.position == @home}
  ]

  defp interact(false, @food, %{displaced?: false, coordination: c}) when c >= 0.30,
    do: {true, 0.0, :food_collected}
  defp interact(true, @home, %{displaced?: false, coordination: c}) when c >= 0.30,
    do: {false, 0.32, :food_consumed}
  defp interact(carrying, _position, _outcome), do: {carrying, 0.0, :none}

  defp local_coherence(_outcome, event) when event in [:food_collected, :food_consumed], do: 1.0
  defp local_coherence(%{consequence: c}, _event)
       when c in [:displacement, :supported_displacement, :supported_stability], do: 0.55
  defp local_coherence(%{consequence: :resisted_displacement}, _event), do: -0.20
  defp local_coherence(_outcome, _event), do: 0.02

  defp physical_goal(%{carrying: false, position: @food}), do: :contact
  defp physical_goal(%{carrying: false, position: p}), do: direction(p, @food)
  defp physical_goal(%{carrying: true, position: @home}), do: :contact
  defp physical_goal(%{carrying: true, position: p}), do: direction(p, @home)

  defp pattern_effect_matches?(_body, _pattern, :contact), do: true
  defp pattern_effect_matches?(body, pattern, desired) do
    body.effect_memory
    |> Map.get(pattern, %{})
    |> Enum.max_by(fn {_direction, weight} -> weight end, fn -> {:none, 0.0} end)
    |> elem(0)
    |> Kernel.==(desired)
  end

  defp recovery_rate(rows) do
    pairs = Enum.chunk_every(rows, 2, 1, :discard)
    recoverable = Enum.filter(pairs, fn [a, _b] -> not a.correct? end)
    fraction(recoverable, fn [_a, b] -> b.correct? end)
  end

  defp field_opts(condition, seed, entity) do
    quality = if condition == :quality_memory, do: @quality_opts, else: []
    [encoding_salt: {:memory_performance, seed, entity}] ++ @base_opts ++ quality
  end

  defp summarize(rows) do
    rows |> Enum.group_by(& &1.condition) |> Map.new(fn {condition, selected} ->
      first_cycles = selected |> Enum.map(& &1.first_cycle) |> Enum.reject(&is_nil/1)
      {condition, %{survived: Enum.count(selected, & &1.survived),
        consumers: Enum.count(selected, & &1.consumed?),
        cycles: mean(Enum.map(selected, &(&1.cycles * 1.0))),
        first_cycle: mean(Enum.map(first_cycles, &(&1 * 1.0))),
        correct: mean(Enum.map(selected, & &1.correct)),
        move_rate: mean(Enum.map(selected, & &1.move_rate)),
        recovery: mean(Enum.map(selected, & &1.recovery)),
        death: mean(Enum.map(selected, &(&1.death * 1.0)))}}
    end)
  end

  defp band(value) when value < 0.25, do: :critical
  defp band(value) when value < 0.55, do: :low
  defp band(value) when value < 0.82, do: :medium
  defp band(_value), do: :high
  defp direction({x, _}, {tx, _}) when x < tx, do: :east
  defp direction({x, _}, {tx, _}) when x > tx, do: :west
  defp direction({_, y}, {_, ty}) when y < ty, do: :south
  defp direction({_, y}, {_, ty}) when y > ty, do: :north
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp fraction([], _predicate), do: 0.0
  defp fraction(rows, predicate), do: Enum.count(rows, predicate) / length(rows)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
