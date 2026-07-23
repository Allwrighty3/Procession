defmodule Procession.Simulation.HomeForagingDecoupledNeedsExperiment do
  @moduledoc """
  Tests corrected food/warmth affordances: carried food may be consumed anywhere;
  home restores warmth independently.
  """

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body
  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @conditions [:coupled_baseline, :decoupled, :decoupled_stagnation]
  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}
  @field_opts [micro_nodes: 64, input_width: 6, activity_retention: 0.84,
    edge_retention: 0.9995, output_edge_retention: 0.9995,
    consolidation_threshold: 4, minimum_compression_gain: 0.0,
    coherence_threshold: 0.025, compression_node_threshold: 0.14,
    compression_coverage_threshold: 0.45, plasticity_threshold: 0.14,
    output_source_threshold: 0.14, output_learning_scale: 0.08,
    output_plasticity_budget: 0.10, recursive_quality_gate: true,
    recursive_ancestor_penalty: 1.0, recursive_min_residual_members: 2,
    minimum_incremental_compression_gain: 1.0, output_source_mode: :rising_residual,
    output_specificity_power: 0.75]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 8)
    teaching_ticks = Keyword.get(opts, :teaching_ticks, 1_200)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 1_200)
    seed = Keyword.get(opts, :seed, 23)
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
      "#{condition}: hunger=#{fmt(s.hunger)} warmth=#{fmt(s.warmth)} " <>
        "eat=#{fmt(s.consume_rate)} warm=#{fmt(s.warm_rate)} carry=#{fmt(s.carry_rate)} " <>
        "move=#{fmt(s.move_rate)} transition=#{fmt(s.transition_rate)} " <>
        "hunger_relief=#{fmt(s.hunger_relief)} warmth_relief=#{fmt(s.warmth_relief)} " <>
        "hunger_switch=#{fmt(s.hunger_switch)} warmth_switch=#{fmt(s.warmth_switch)} " <>
        "cycles=#{fmt(s.cycles)} vitality_slope=#{fmt(s.vitality_slope)}"
    end)

    Enum.join(["Decoupled hunger/warmth comparison",
      "carried food consumable anywhere; home restores warmth only",
      "teaching=#{result.teaching_ticks} withdrawal=#{result.withdrawal_ticks}" | lines], "\n")
  end

  defp run_one(condition, entity, seed, teaching_ticks, total) do
    opts = [encoding_salt: {:decoupled_needs, seed, entity}] ++ @field_opts
    initial = %{body: Body.new(), field: Field.new(opts), position: @home,
      carrying: false, hunger: 0.20, warmth: 1.0, vitality: 0.995,
      last_pattern: nil, last_outcome: :none, stagnant: 0, records: [], cycles: 0}

    final = Enum.reduce_while(1..total, initial, fn tick, state ->
      teaching? = tick <= teaching_ticks
      field = Field.sense(state.field, sensory_features(state), opts)
      desired = physical_goal(state, condition)
      pattern = select_pattern(condition, field, state, tick, seed, entity, teaching?, opts)
      {natural_body, natural} = Body.attempt(state.body, pattern, state.position, tick,
        seed: seed + entity * 1_003, bounds: @bounds)
      {body, outcome, position, assisted?} =
        apply_support(state.body, natural_body, natural, state.position, pattern, desired, teaching?)
      {carrying, intake, event} = interact(condition, state.carrying, position, outcome)

      hunger_before = state.hunger
      hunger = min(1.0, hunger_before + 0.00045)
      hunger = if event == :food_consumed, do: max(0.0, hunger - 0.72), else: hunger
      warmth_before = state.warmth
      warmth = if position == @home, do: min(1.0, warmth_before + 0.015),
        else: max(0.0, warmth_before - 0.00030)
      hunger_relief = max(0.0, hunger_before - hunger)
      warmth_relief = max(0.0, warmth - warmth_before)

      field = Field.record_output(field, pattern, coherence(outcome, event), opts)
      transitioned? = position != state.position or carrying != state.carrying or
        hunger_relief > 0.0 or warmth_relief > 0.0
      stagnant = if transitioned?, do: 0, else: state.stagnant + 1
      effort = if assisted?, do: 0.00004, else: 0.00020
      vitality = max(0.0, min(1.0, state.vitality - 0.00008 - effort -
        0.00018 * hunger - 0.00012 * (1.0 - warmth) + intake))
      cycle? = event == :food_consumed and not teaching?

      record = %{teaching?: teaching?, pattern: pattern, hunger: hunger, warmth: warmth,
        hunger_relief: hunger_relief, warmth_relief: warmth_relief,
        consumed?: event == :food_consumed, warmed?: warmth_relief > 0.0,
        carry_acquired?: not state.carrying and carrying,
        displaced?: outcome.displaced?, transitioned?: transitioned?, vitality: vitality}
      next = %{state | body: body, field: field, position: position, carrying: carrying,
        hunger: hunger, warmth: warmth, vitality: vitality, last_pattern: pattern,
        last_outcome: outcome.consequence, stagnant: stagnant,
        records: [record | state.records], cycles: state.cycles + if(cycle?, do: 1, else: 0)}

      if vitality > 0.0 and warmth > 0.0, do: {:cont, next}, else: {:halt, next}
    end)

    withdrawal = final.records |> Enum.reverse() |> Enum.reject(& &1.teaching?)
    %{condition: condition, cycles: final.cycles,
      hunger: mean(Enum.map(withdrawal, & &1.hunger)), warmth: mean(Enum.map(withdrawal, & &1.warmth)),
      consume_rate: fraction(withdrawal, & &1.consumed?), warm_rate: fraction(withdrawal, & &1.warmed?),
      carry_rate: fraction(withdrawal, & &1.carry_acquired?), move_rate: fraction(withdrawal, & &1.displaced?),
      transition_rate: fraction(withdrawal, & &1.transitioned?),
      hunger_relief: mean(Enum.map(withdrawal, & &1.hunger_relief)),
      warmth_relief: mean(Enum.map(withdrawal, & &1.warmth_relief)),
      hunger_switch: switch_latency(withdrawal, :hunger_relief),
      warmth_switch: switch_latency(withdrawal, :warmth_relief),
      vitality_slope: slope(withdrawal, :vitality)}
  end

  defp select_pattern(condition, field, state, tick, seed, entity, teaching?, opts) do
    patterns = Body.patterns()
    scores = Field.output_scores(field, patterns, opts)
    exploration = if teaching?, do: 0.30, else: exploration(condition, state)
    penalty = if condition == :decoupled_stagnation and state.stagnant >= 12,
      do: max(0.05, :math.pow(0.72, div(state.stagnant, 12))), else: 1.0

    patterns
    |> Enum.map(fn pattern ->
      noise = :erlang.phash2({:decoupled_select, seed, entity, tick, pattern}, 10_000) / 10_000
      score = Map.get(scores, pattern, 0.0) * (1.0 - exploration) + noise * exploration
      {pattern, if(pattern == state.last_pattern, do: score * penalty, else: score)}
    end)
    |> Enum.max_by(fn {pattern, score} -> {score, pattern} end)
    |> elem(0)
  end

  defp exploration(:decoupled_stagnation, %{stagnant: n}), do: min(0.60, 0.10 + n * 0.006)
  defp exploration(_, _), do: 0.10

  defp sensory_features(state), do: [
    {:position, state.position}, {:carrying, state.carrying},
    {:hunger, band(state.hunger)}, {:warmth, band(state.warmth)},
    {:vitality, band(state.vitality)}, {:last_pattern, state.last_pattern},
    {:last_outcome, state.last_outcome}, {:food_contact, state.position == @food},
    {:home_contact, state.position == @home}
  ]

  defp interact(:coupled_baseline, true, @home, %{displaced?: false, coordination: c}) when c >= 0.30,
    do: {false, 0.24, :food_consumed}
  defp interact(condition, true, _position, %{displaced?: false, coordination: c})
       when condition in [:decoupled, :decoupled_stagnation] and c >= 0.30,
    do: {false, 0.24, :food_consumed}
  defp interact(_condition, false, @food, %{displaced?: false, coordination: c}) when c >= 0.30,
    do: {true, 0.0, :food_collected}
  defp interact(_condition, carrying, _position, _outcome), do: {carrying, 0.0, :none}

  defp physical_goal(%{carrying: false, position: @food}, _), do: :contact
  defp physical_goal(%{carrying: false, position: p}, _), do: direction(p, @food)
  defp physical_goal(%{carrying: true, position: @home}, :coupled_baseline), do: :contact
  defp physical_goal(%{carrying: true, position: p}, :coupled_baseline), do: direction(p, @home)
  defp physical_goal(%{carrying: true}, _), do: :contact

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

  defp coherence(_outcome, event) when event in [:food_collected, :food_consumed], do: 1.0
  defp coherence(%{consequence: c}, _) when c in [:displacement, :supported_displacement, :supported_stability], do: 0.55
  defp coherence(%{consequence: :resisted_displacement}, _), do: -0.35
  defp coherence(_, _), do: -0.03

  defp switch_latency(rows, key) do
    indexes = rows |> Enum.with_index() |> Enum.filter(fn {r, _} -> Map.fetch!(r, key) > 0.0 end)
    latencies = Enum.map(indexes, fn {r, i} ->
      rows |> Enum.drop(i + 1) |> Enum.find_index(&(&1.pattern != r.pattern))
    end) |> Enum.reject(&is_nil/1)
    mean(Enum.map(latencies, &(&1 * 1.0)))
  end

  defp summarize(rows), do: rows |> Enum.group_by(& &1.condition) |> Map.new(fn {condition, selected} ->
    keys = [:hunger, :warmth, :consume_rate, :warm_rate, :carry_rate, :move_rate,
      :transition_rate, :hunger_relief, :warmth_relief, :hunger_switch, :warmth_switch,
      :vitality_slope]
    values = Map.new(keys, fn key -> {key, mean(Enum.map(selected, &Map.fetch!(&1, key)))} end)
    {condition, Map.put(values, :cycles, mean(Enum.map(selected, &(&1.cycles * 1.0))))}
  end)

  defp slope([], _), do: 0.0
  defp slope([_], _), do: 0.0
  defp slope(rows, key), do: (Map.fetch!(List.last(rows), key) - Map.fetch!(hd(rows), key)) / max(length(rows) - 1, 1)
  defp band(v) when v < 0.25, do: :critical
  defp band(v) when v < 0.55, do: :low
  defp band(v) when v < 0.82, do: :medium
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
end
