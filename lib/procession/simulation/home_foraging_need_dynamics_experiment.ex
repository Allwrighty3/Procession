defmodule Procession.Simulation.HomeForagingNeedDynamicsExperiment do
  @moduledoc """
  Measures closed-loop learner behavior with continuous need pressure.

  Conditions share bodies, seeds, teaching and sensory experience. `:quality_memory`
  uses the current quality-controlled memory path. `:need_sensitive_memory` also
  exposes finer hunger state and records post-satisfaction inhibition for the output
  that was active when hunger fell. `:memory_ignored` remains the exploratory control.
  """

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body
  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @conditions [:memory_ignored, :quality_memory, :need_sensitive_memory]
  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}

  @base_opts [
    micro_nodes: 64,
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
    output_plasticity_budget: 0.10,
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
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 4_800)
    seed = Keyword.get(opts, :seed, 11)
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
      "#{condition}: cycles=#{fmt(s.cycles)} hunger=#{fmt(s.mean_hunger)} " <>
        "hunger_slope=#{fmt(s.hunger_slope)} relief=#{fmt(s.relief)} " <>
        "relief_duration=#{fmt(s.relief_duration)} repeat=#{fmt(s.post_relief_repeat)} " <>
        "move=#{fmt(s.move_rate)} transition=#{fmt(s.transition_rate)} " <>
        "vitality_slope=#{fmt(s.vitality_slope)} stuck=#{fmt(s.stuck_run)}"
    end)

    Enum.join([
      "Continuous need-dynamics memory comparison",
      "graded hunger, post-satisfaction inhibition, and closed-loop behavior",
      "teaching=#{result.teaching_ticks} withdrawal=#{result.withdrawal_ticks}" | lines
    ], "\n")
  end

  defp run_one(condition, entity, seed, teaching_ticks, total) do
    opts = field_opts(seed, entity)
    initial = %{body: Body.new(), field: Field.new(opts), position: @home,
      carrying: false, hunger: 0.20, vitality: 0.995, warmth: 1.0,
      last_pattern: nil, last_outcome: :none, records: [], cycles: 0}

    final = Enum.reduce_while(1..total, initial, fn tick, state ->
      teaching? = tick <= teaching_ticks
      field = Field.sense(state.field, sensory_features(state, condition), opts)
      desired = physical_goal(state)
      pattern = select_pattern(condition, field, state.body, tick, seed, entity, teaching_ticks, opts)
      {natural_body, natural} = Body.attempt(state.body, pattern, state.position, tick,
        seed: seed + entity * 1_003, bounds: @bounds)
      {body, outcome, position, assisted?} =
        apply_support(state.body, natural_body, natural, state.position, pattern, desired, teaching?)
      {carrying, intake, event} = interact(state.carrying, position, outcome)

      hunger_before = state.hunger
      hunger = state.hunger |> Kernel.+(0.00045) |> min(1.0)
      hunger = if event == :food_consumed, do: max(0.0, hunger - 0.72), else: hunger
      relief = max(0.0, hunger_before - hunger)

      field = Field.record_output(field, pattern, local_coherence(outcome, event), opts)
      field = maybe_inhibit_satisfied_output(condition, field, pattern, relief, state, hunger, opts)

      warmth = if position == @home, do: min(1.0, state.warmth + 0.015),
        else: max(0.0, state.warmth - 0.00030)
      effort = if assisted?, do: 0.00004, else: 0.00020
      hunger_cost = 0.00018 * hunger
      vitality = max(0.0, min(1.0, state.vitality - 0.00008 - effort - hunger_cost + intake))
      cycle? = event == :food_consumed and not teaching?
      transitioned? = position != state.position or carrying != state.carrying or relief > 0.0

      record = %{tick: tick, teaching?: teaching?, pattern: pattern, hunger: hunger,
        relief: relief, vitality: vitality, displaced?: outcome.displaced?,
        transitioned?: transitioned?, event: event}
      next = %{state | body: body, field: field, position: position, carrying: carrying,
        hunger: hunger, vitality: vitality, warmth: warmth, last_pattern: pattern,
        last_outcome: outcome.consequence, records: [record | state.records],
        cycles: state.cycles + if(cycle?, do: 1, else: 0)}

      if vitality > 0.0 and warmth > 0.0, do: {:cont, next}, else: {:halt, next}
    end)

    withdrawal = final.records |> Enum.reverse() |> Enum.reject(& &1.teaching?)
    %{condition: condition, cycles: final.cycles,
      mean_hunger: mean(Enum.map(withdrawal, & &1.hunger)),
      hunger_slope: slope(withdrawal, :hunger),
      relief: mean(Enum.map(withdrawal, & &1.relief)),
      relief_duration: relief_duration(withdrawal),
      post_relief_repeat: post_relief_repeat(withdrawal),
      move_rate: fraction(withdrawal, & &1.displaced?),
      transition_rate: fraction(withdrawal, & &1.transitioned?),
      vitality_slope: slope(withdrawal, :vitality),
      stuck_run: longest_stuck_run(withdrawal)}
  end

  defp maybe_inhibit_satisfied_output(:need_sensitive_memory, field, pattern, relief, state, hunger, opts)
       when relief > 0.05 do
    post = %{state | hunger: hunger, carrying: false, position: @home,
      last_pattern: pattern, last_outcome: :need_reduced}
    field
    |> Field.sense(sensory_features(post, :need_sensitive_memory), opts)
    |> Field.record_output(pattern, -min(1.0, 0.35 + relief), opts)
  end
  defp maybe_inhibit_satisfied_output(_, field, _pattern, _relief, _state, _hunger, _opts), do: field

  defp select_pattern(:memory_ignored, _field, body, tick, seed, entity, _teaching, _opts),
    do: Body.choose_pattern(body, tick, seed + entity * 149)
  defp select_pattern(_condition, field, _body, tick, seed, entity, teaching_ticks, opts) do
    patterns = Body.patterns()
    scores = Field.output_scores(field, patterns, opts)
    exploration = if tick <= teaching_ticks, do: 0.30, else: 0.10
    patterns
    |> Enum.map(fn pattern ->
      noise = :erlang.phash2({:need_select, seed, entity, tick, pattern}, 10_000) / 10_000
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

  defp sensory_features(state, condition) do
    hunger_feature = if condition == :need_sensitive_memory,
      do: {:hunger_decile, trunc(state.hunger * 10)}, else: {:hunger, band(state.hunger)}
    [
      {:position, state.position}, {:carrying, state.carrying}, hunger_feature,
      {:warmth, band(state.warmth)}, {:vitality, band(state.vitality)},
      {:last_pattern, state.last_pattern}, {:last_outcome, state.last_outcome},
      {:food_contact, state.position == @food}, {:home_contact, state.position == @home}
    ]
  end

  defp interact(false, @food, %{displaced?: false, coordination: c}) when c >= 0.30,
    do: {true, 0.0, :food_collected}
  defp interact(true, @home, %{displaced?: false, coordination: c}) when c >= 0.30,
    do: {false, 0.24, :food_consumed}
  defp interact(carrying, _position, _outcome), do: {carrying, 0.0, :none}

  defp local_coherence(_outcome, event) when event in [:food_collected, :food_consumed], do: 1.0
  defp local_coherence(%{consequence: c}, _event)
       when c in [:displacement, :supported_displacement, :supported_stability], do: 0.55
  defp local_coherence(%{consequence: :resisted_displacement}, _event), do: -0.35
  defp local_coherence(_outcome, _event), do: -0.03

  defp physical_goal(%{carrying: false, position: @food}), do: :contact
  defp physical_goal(%{carrying: false, position: p}), do: direction(p, @food)
  defp physical_goal(%{carrying: true, position: @home}), do: :contact
  defp physical_goal(%{carrying: true, position: p}), do: direction(p, @home)

  defp relief_duration(rows) do
    events = Enum.with_index(rows) |> Enum.filter(fn {r, _} -> r.relief > 0.05 end)
    durations = Enum.map(events, fn {_r, i} ->
      rows |> Enum.drop(i) |> Enum.take_while(&(&1.hunger < 0.50)) |> length()
    end)
    mean(Enum.map(durations, &(&1 * 1.0)))
  end

  defp post_relief_repeat(rows) do
    pairs = Enum.chunk_every(rows, 2, 1, :discard)
    relevant = Enum.filter(pairs, fn [a, _b] -> a.relief > 0.05 end)
    fraction(relevant, fn [a, b] -> a.pattern == b.pattern end)
  end

  defp longest_stuck_run(rows) do
    {best, current} = Enum.reduce(rows, {0, 0}, fn row, {best, current} ->
      next = if row.transitioned?, do: 0, else: current + 1
      {max(best, next), next}
    end)
    max(best, current) * 1.0
  end

  defp slope([], _key), do: 0.0
  defp slope([_], _key), do: 0.0
  defp slope(rows, key) do
    first = Map.fetch!(hd(rows), key)
    last = Map.fetch!(List.last(rows), key)
    (last - first) / max(length(rows) - 1, 1)
  end

  defp field_opts(seed, entity), do: [encoding_salt: {:need_dynamics, seed, entity}] ++ @base_opts
  defp band(value) when value < 0.25, do: :critical
  defp band(value) when value < 0.55, do: :low
  defp band(value) when value < 0.82, do: :medium
  defp band(_), do: :high
  defp direction({x, _}, {tx, _}) when x < tx, do: :east
  defp direction({x, _}, {tx, _}) when x > tx, do: :west
  defp direction({_, y}, {_, ty}) when y < ty, do: :south
  defp direction({_, y}, {_, ty}) when y > ty, do: :north
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp fraction([], _), do: 0.0
  defp fraction(rows, pred), do: Enum.count(rows, pred) / length(rows)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)

  defp summarize(rows) do
    rows |> Enum.group_by(& &1.condition) |> Map.new(fn {condition, selected} ->
      keys = [:cycles, :mean_hunger, :hunger_slope, :relief, :relief_duration,
        :post_relief_repeat, :move_rate, :transition_rate, :vitality_slope, :stuck_run]
      {condition, Map.new(keys, fn key ->
        {key, mean(Enum.map(selected, &(Map.fetch!(&1, key) * 1.0)))}
      end)}
    end)
  end
end
