defmodule Procession.Simulation.HomeForagingRecursiveMemoryIntegration do
  @moduledoc """
  Verifies that the existing developmental memory plane can recursively consolidate
  experience and influence learner-owned motor-pattern selection.

  The matched cohorts receive the same local sensory stream, body, caregiver support,
  and seeds. Only `:memory_plane` uses field output scores during selection; the
  `:memory_disabled` cohort retains the field for structural comparison but ignores it.
  """

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body
  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @conditions [:memory_disabled, :memory_plane]
  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}

  @field_opts [
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

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 12)
    seed = Keyword.get(opts, :seed, 1)
    teaching_ticks = Keyword.get(opts, :teaching_ticks, 2_400)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 1_200)
    total = teaching_ticks + withdrawal_ticks

    rows =
      for condition <- @conditions, entity <- 1..population do
        run_one(condition, entity, seed, teaching_ticks, total)
      end

    %{population: population, teaching_ticks: teaching_ticks, total_ticks: total,
      rows: rows, summary: summarize(rows)}
  end

  def report(result) do
    lines = Enum.map(@conditions, fn condition ->
      s = result.summary[condition]
      "#{condition}: survived=#{s.survived}/#{result.population} " <>
        "food=#{s.food}/#{result.population} collected=#{s.collected}/#{result.population} " <>
        "consumed=#{s.consumed}/#{result.population} generated=#{fmt(s.generated)} " <>
        "recursive=#{fmt(s.recursive)} max_depth=#{fmt(s.max_depth)} " <>
        "withdrawal_correct=#{fmt(s.withdrawal_correct)} score_margin=#{fmt(s.score_margin)}"
    end)

    Enum.join([
      "Recursive memory-plane motor integration",
      "matched local experience; no experiment-local goal-to-pattern repertoire",
      "teaching=#{result.teaching_ticks} withdrawal=#{result.total_ticks - result.teaching_ticks}"
      | lines
    ], "\n")
  end

  defp run_one(condition, entity, seed, teaching_ticks, total) do
    state = %{body: Body.new(), field: Field.new(@field_opts), position: @home,
      carrying: false, vitality: 0.995, warmth: 1.0, last_pattern: nil,
      last_outcome: :none, records: []}

    final = Enum.reduce_while(1..total, state, fn tick, state ->
      teaching? = tick <= teaching_ticks
      features = sensory_features(state)
      field = Field.sense(state.field, features, field_opts(seed, entity))
      desired = physical_goal(state)
      pattern = select_pattern(condition, field, state.body, tick, seed, entity)

      {natural_body, natural} = Body.attempt(state.body, pattern, state.position, tick,
        seed: seed + entity * 1_003, bounds: @bounds)

      {body, outcome, position, assisted?} =
        apply_support(state.body, natural_body, natural, state.position, pattern, desired, teaching?)

      {carrying, intake, event} = interact(state.carrying, position, outcome)
      coherence = local_coherence(state, outcome, event)
      field = Field.record_output(field, pattern, coherence,
        field_opts(seed, entity) ++ [output_learning_scale: 0.08])

      warmth = if position == @home, do: min(1.0, state.warmth + 0.02),
        else: max(0.0, state.warmth - 0.00025)
      cost = if assisted?, do: 0.00005, else: 0.00018
      vitality = max(0.0, min(1.0, state.vitality - 0.00012 - cost + intake))
      scores = Field.output_scores(field, Body.patterns(), field_opts(seed, entity))
      correct? = pattern_effect_matches?(body, pattern, desired)
      margin = score_margin(scores, pattern, desired, body)

      record = %{tick: tick, teaching?: teaching?, position: position, pattern: pattern,
        desired: desired, correct?: correct?, event: event, margin: margin}

      next = %{state | body: body, field: field, position: position, carrying: carrying,
        vitality: vitality, warmth: warmth, last_pattern: pattern,
        last_outcome: outcome.consequence, records: [record | state.records]}

      if vitality > 0.0 and warmth > 0.0, do: {:cont, next}, else: {:halt, next}
    end)

    records = Enum.reverse(final.records)
    withdrawal = Enum.filter(records, &(not &1.teaching?))
    depths = generated_depths(final.field.sensory)

    %{condition: condition, survived: length(records) == total,
      food: Enum.any?(records, &(&1.position == @food)),
      collected: Enum.any?(records, &(&1.event == :food_collected)),
      consumed: Enum.any?(records, &(&1.event == :food_consumed)),
      generated: map_size(depths), recursive: Enum.count(depths, fn {_id, d} -> d >= 2 end),
      max_depth: depths |> Map.values() |> Enum.max(fn -> 0 end),
      withdrawal_correct: fraction(withdrawal, & &1.correct?),
      score_margin: mean(Enum.map(withdrawal, & &1.margin))}
  end

  defp sensory_features(state) do
    [{:position, state.position}, {:carrying, state.carrying},
     {:warmth, band(state.warmth)}, {:vitality, band(state.vitality)},
     {:last_pattern, state.last_pattern}, {:last_outcome, state.last_outcome},
     {:food_contact, state.position == @food}, {:home_contact, state.position == @home}]
  end

  defp select_pattern(:memory_disabled, _field, body, tick, seed, entity),
    do: Body.choose_pattern(body, tick, seed + entity * 149)

  defp select_pattern(:memory_plane, field, body, tick, seed, entity) do
    patterns = Body.patterns()
    scores = Field.output_scores(field, patterns, field_opts(seed, entity))
    exploration = if tick <= 2_400, do: 0.30, else: 0.06

    patterns
    |> Enum.map(fn pattern ->
      noise = :erlang.phash2({:memory_select, seed, entity, tick, pattern}, 10_000) / 10_000
      {pattern, Map.get(scores, pattern, 0.0) * (1.0 - exploration) + noise * exploration}
    end)
    |> Enum.max_by(fn {pattern, score} -> {score, pattern} end)
    |> elem(0)
  end

  defp apply_support(before, natural_body, natural, position, pattern, desired, false),
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
    do: {false, 0.30, :food_consumed}
  defp interact(carrying, _position, _outcome), do: {carrying, 0.0, :none}

  defp local_coherence(_state, _outcome, event) when event in [:food_collected, :food_consumed], do: 1.0
  defp local_coherence(_state, %{consequence: c}, _event)
       when c in [:displacement, :supported_displacement, :supported_stability], do: 0.55
  defp local_coherence(_state, %{consequence: :resisted_displacement}, _event), do: -0.20
  defp local_coherence(_state, _outcome, _event), do: 0.02

  defp physical_goal(%{carrying: false, position: @food}), do: :contact
  defp physical_goal(%{carrying: false, position: p}), do: direction(p, @food)
  defp physical_goal(%{carrying: true, position: @home}), do: :contact
  defp physical_goal(%{carrying: true, position: p}), do: direction(p, @home)

  defp pattern_effect_matches?(_body, _pattern, :contact), do: true
  defp pattern_effect_matches?(body, pattern, desired) do
    effects = Map.get(body.effect_memory, pattern, %{})
    case Enum.max_by(effects, fn {_direction, weight} -> weight end, fn -> {:none, 0.0} end) do
      {^desired, _} -> true
      _ -> false
    end
  end

  defp score_margin(scores, selected, desired, body) do
    selected_score = Map.get(scores, selected, 0.0)
    best_correct = Body.patterns()
      |> Enum.filter(&pattern_effect_matches?(body, &1, desired))
      |> Enum.map(&Map.get(scores, &1, 0.0))
      |> Enum.max(fn -> 0.0 end)
    selected_score - best_correct
  end

  defp generated_depths(sensory) do
    Enum.reduce(sensory.generated, %{}, fn id, memo ->
      {_depth, memo} = node_depth(id, sensory, memo, MapSet.new())
      memo
    end)
  end

  defp node_depth(id, sensory, memo, visiting) do
    cond do
      Map.has_key?(memo, id) -> {Map.fetch!(memo, id), memo}
      MapSet.member?(visiting, id) -> {0, memo}
      true ->
        node = Map.fetch!(sensory.nodes, id)
        visiting = MapSet.put(visiting, id)
        {member_depths, memo} = Enum.map_reduce(node.support, memo, fn member, acc ->
          member_node = Map.fetch!(sensory.nodes, member)
          if member_node.kind == :generated do
            node_depth(member, sensory, acc, visiting)
          else
            {0, acc}
          end
        end)
        depth = 1 + Enum.max(member_depths, fn -> 0 end)
        {depth, Map.put(memo, id, depth)}
    end
  end

  defp field_opts(seed, entity), do: [encoding_salt: {:recursive_memory, seed, entity}] ++ @field_opts
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

  defp summarize(rows) do
    rows |> Enum.group_by(& &1.condition) |> Map.new(fn {condition, selected} ->
      {condition, %{survived: Enum.count(selected, & &1.survived),
        food: Enum.count(selected, & &1.food), collected: Enum.count(selected, & &1.collected),
        consumed: Enum.count(selected, & &1.consumed),
        generated: mean(Enum.map(selected, &(&1.generated * 1.0))),
        recursive: mean(Enum.map(selected, &(&1.recursive * 1.0))),
        max_depth: mean(Enum.map(selected, &(&1.max_depth * 1.0))),
        withdrawal_correct: mean(Enum.map(selected, & &1.withdrawal_correct)),
        score_margin: mean(Enum.map(selected, & &1.score_margin))}}
    end)
  end
end
