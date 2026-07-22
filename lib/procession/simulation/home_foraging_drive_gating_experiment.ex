defmodule Procession.Simulation.HomeForagingDriveGatingExperiment do
  @moduledoc """
  Measures whether a saturated need monopolizes motor selection.

  Raw drive exposes hunger directly. Context-gated drive exposes hunger only as part
  of the current local bodily situation. Stagnation recovery also suppresses a
  dominant output after repeated high-need ticks without a meaningful transition.
  """

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body
  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @conditions [:direct_drive, :context_gated, :stagnation_recovery]
  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}
  @field_opts [
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
    population = Keyword.get(opts, :population, 12)
    teaching_ticks = Keyword.get(opts, :teaching_ticks, 2_400)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 2_400)
    seed = Keyword.get(opts, :seed, 17)
    total = teaching_ticks + withdrawal_ticks

    rows =
      for condition <- @conditions, entity <- 1..population do
        run_one(condition, entity, seed, teaching_ticks, total)
      end

    %{population: population, teaching_ticks: teaching_ticks,
      withdrawal_ticks: withdrawal_ticks, rows: rows, summary: summarize(rows)}
  end

  def report(result) do
    lines = Enum.map(@conditions, fn condition ->
      s = result.summary[condition]
      "#{condition}: hunger=#{fmt(s.mean_hunger)} saturated=#{fmt(s.saturation)} " <>
        "dominance=#{fmt(s.dominance)} entropy=#{fmt(s.entropy)} repeat=#{fmt(s.repeat_run)} " <>
        "eligible=#{fmt(s.eligible)} move=#{fmt(s.move_rate)} transition=#{fmt(s.transition_rate)} " <>
        "progress=#{fmt(s.progress_rate)} carry=#{fmt(s.carry_rate)} cycles=#{fmt(s.cycles)} " <>
        "vitality_slope=#{fmt(s.vitality_slope)}"
    end)

    Enum.join([
      "Continuous drive-gating comparison",
      "raw drive vs contextual drive vs stagnation recovery",
      "teaching=#{result.teaching_ticks} withdrawal=#{result.withdrawal_ticks}" | lines
    ], "\n")
  end

  defp run_one(condition, entity, seed, teaching_ticks, total) do
    opts = [encoding_salt: {:drive_gating, seed, entity}] ++ @field_opts
    initial = %{body: Body.new(), field: Field.new(opts), position: @home,
      carrying: false, hunger: 0.20, vitality: 0.995, warmth: 1.0,
      last_pattern: nil, last_outcome: :none, stagnant: 0, records: [], cycles: 0}

    final = Enum.reduce_while(1..total, initial, fn tick, state ->
      teaching? = tick <= teaching_ticks
      field = Field.sense(state.field, sensory_features(state, condition), opts)
      desired = physical_goal(state)
      {pattern, scores, dominance} = select_pattern(condition, field, state, tick,
        seed, entity, teaching?, opts)
      {natural_body, natural} = Body.attempt(state.body, pattern, state.position, tick,
        seed: seed + entity * 1_003, bounds: @bounds)
      {body, outcome, position, assisted?} =
        apply_support(state.body, natural_body, natural, state.position, pattern, desired, teaching?)
      {carrying, intake, event} = interact(state.carrying, position, outcome)

      hunger = min(1.0, state.hunger + 0.00045)
      hunger = if event == :food_consumed, do: max(0.0, hunger - 0.72), else: hunger
      field = Field.record_output(field, pattern, local_coherence(outcome, event), opts)
      transitioned? = position != state.position or carrying != state.carrying or event == :food_consumed
      stagnant = if transitioned?, do: 0, else: state.stagnant + 1
      warmth = if position == @home, do: min(1.0, state.warmth + 0.015),
        else: max(0.0, state.warmth - 0.00030)
      effort = if assisted?, do: 0.00004, else: 0.00020
      vitality = max(0.0, min(1.0,
        state.vitality - 0.00008 - effort - 0.00018 * hunger + intake))
      progress? = progress?(state.position, position, state.carrying, carrying)
      eligible? = pattern_eligible?(body, pattern, desired, outcome, event)
      cycle? = event == :food_consumed and not teaching?

      record = %{teaching?: teaching?, pattern: pattern, hunger: hunger,
        saturated?: hunger >= 0.90, dominance: dominance, entropy: entropy(scores),
        eligible?: eligible?, displaced?: outcome.displaced?, transitioned?: transitioned?,
        progress?: progress?, carry_acquired?: not state.carrying and carrying,
        vitality: vitality}
      next = %{state | body: body, field: field, position: position, carrying: carrying,
        hunger: hunger, vitality: vitality, warmth: warmth, last_pattern: pattern,
        last_outcome: outcome.consequence, stagnant: stagnant,
        records: [record | state.records], cycles: state.cycles + if(cycle?, do: 1, else: 0)}

      if vitality > 0.0 and warmth > 0.0, do: {:cont, next}, else: {:halt, next}
    end)

    withdrawal = final.records |> Enum.reverse() |> Enum.reject(& &1.teaching?)
    %{condition: condition, cycles: final.cycles,
      mean_hunger: mean(Enum.map(withdrawal, & &1.hunger)),
      saturation: fraction(withdrawal, & &1.saturated?),
      dominance: mean(Enum.map(withdrawal, & &1.dominance)),
      entropy: mean(Enum.map(withdrawal, & &1.entropy)),
      repeat_run: longest_repeat(withdrawal),
      eligible: fraction(withdrawal, & &1.eligible?),
      move_rate: fraction(withdrawal, & &1.displaced?),
      transition_rate: fraction(withdrawal, & &1.transitioned?),
      progress_rate: fraction(withdrawal, & &1.progress?),
      carry_rate: fraction(withdrawal, & &1.carry_acquired?),
      vitality_slope: slope(withdrawal, :vitality)}
  end

  defp select_pattern(condition, field, state, tick, seed, entity, teaching?, opts) do
    patterns = Body.patterns()
    raw = Field.output_scores(field, patterns, opts)
    penalty = stagnation_penalty(condition, state)
    exploration = if teaching?, do: 0.30, else: exploration(condition, state)

    scored = Map.new(patterns, fn pattern ->
      noise = :erlang.phash2({:drive_gate, seed, entity, tick, pattern}, 10_000) / 10_000
      score = Map.get(raw, pattern, 0.0) * (1.0 - exploration) + noise * exploration
      score = if pattern == state.last_pattern, do: score * penalty, else: score
      {pattern, score}
    end)
    {pattern, top} = Enum.max_by(scored, fn {pattern, score} -> {score, pattern} end)
    positive_total = Enum.sum(Enum.map(scored, fn {_p, score} -> max(score, 0.0) end))
    dominance = if positive_total > 0.0, do: max(top, 0.0) / positive_total, else: 0.0
    {pattern, scored, dominance}
  end

  defp stagnation_penalty(:stagnation_recovery, %{hunger: h, stagnant: n}) when h >= 0.90 and n >= 12,
    do: max(0.05, :math.pow(0.72, div(n, 12)))
  defp stagnation_penalty(_, _), do: 1.0
  defp exploration(:stagnation_recovery, %{hunger: h, stagnant: n}) when h >= 0.90,
    do: min(0.60, 0.10 + n * 0.006)
  defp exploration(_, _), do: 0.10

  defp sensory_features(state, :direct_drive), do: base_features(state) ++ [{:hunger, band(state.hunger)}]
  defp sensory_features(state, _condition) do
    situation = {state.carrying, state.position == @food, state.position == @home,
      band(state.hunger)}
    base_features(state) ++ [{:drive_context, situation}]
  end
  defp base_features(state), do: [
    {:position, state.position}, {:carrying, state.carrying},
    {:warmth, band(state.warmth)}, {:vitality, band(state.vitality)},
    {:last_pattern, state.last_pattern}, {:last_outcome, state.last_outcome},
    {:food_contact, state.position == @food}, {:home_contact, state.position == @home}
  ]

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

  defp pattern_eligible?(_body, _pattern, :contact, _outcome, event),
    do: event in [:food_collected, :food_consumed]
  defp pattern_eligible?(body, pattern, desired, _outcome, _event) do
    body.effect_memory |> Map.get(pattern, %{})
    |> Enum.max_by(fn {_direction, weight} -> weight end, fn -> {:none, 0.0} end)
    |> elem(0) |> Kernel.==(desired)
  end

  defp progress?(before, after_, carrying_before, carrying_after) when carrying_before != carrying_after,
    do: true
  defp progress?(before, after_, false, false), do: distance(after_, @food) < distance(before, @food)
  defp progress?(before, after_, true, true), do: distance(after_, @home) < distance(before, @home)
  defp distance({x, y}, {tx, ty}), do: abs(x - tx) + abs(y - ty)

  defp entropy(scores) do
    values = Enum.map(scores, fn {_p, score} -> max(score, 0.0) end)
    total = Enum.sum(values)
    if total <= 0.0, do: 0.0, else: values |> Enum.map(&(&1 / total))
      |> Enum.reject(&(&1 <= 0.0)) |> Enum.reduce(0.0, fn p, acc -> acc - p * :math.log(p) end)
  end

  defp longest_repeat(rows) do
    {_last, best, current} = Enum.reduce(rows, {nil, 0, 0}, fn row, {last, best, current} ->
      next = if row.pattern == last, do: current + 1, else: 1
      {row.pattern, max(best, next), next}
    end)
    best * 1.0
  end

  defp summarize(rows), do: rows |> Enum.group_by(& &1.condition) |> Map.new(fn {condition, selected} ->
    {condition, %{cycles: mean(Enum.map(selected, &(&1.cycles * 1.0))),
      mean_hunger: mean(Enum.map(selected, & &1.mean_hunger)),
      saturation: mean(Enum.map(selected, & &1.saturation)),
      dominance: mean(Enum.map(selected, & &1.dominance)),
      entropy: mean(Enum.map(selected, & &1.entropy)),
      repeat_run: mean(Enum.map(selected, & &1.repeat_run)),
      eligible: mean(Enum.map(selected, & &1.eligible)),
      move_rate: mean(Enum.map(selected, & &1.move_rate)),
      transition_rate: mean(Enum.map(selected, & &1.transition_rate)),
      progress_rate: mean(Enum.map(selected, & &1.progress_rate)),
      carry_rate: mean(Enum.map(selected, & &1.carry_rate)),
      vitality_slope: mean(Enum.map(selected, & &1.vitality_slope))}}
  end)

  defp slope([], _key), do: 0.0
  defp slope([_], _key), do: 0.0
  defp slope(rows, key), do: (Map.fetch!(List.last(rows), key) - Map.fetch!(hd(rows), key)) /
    max(length(rows) - 1, 1)
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
  defp fraction([], _predicate), do: 0.0
  defp fraction(rows, predicate), do: Enum.count(rows, predicate) / length(rows)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end