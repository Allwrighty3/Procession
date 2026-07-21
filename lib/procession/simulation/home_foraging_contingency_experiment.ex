defmodule Procession.Simulation.HomeForagingContingencyExperiment do
  @moduledoc "Transition-sensitive home-foraging with a slow, long-lived learner."

  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @actions [:manipulate, :wait, :north, :south, :east, :west]
  @conditions [:abrupt_assistance, :staged_assistance]
  @variants [:standard, :slow_long_lived]
  @home {0, 0}
  @field_opts [micro_nodes: 64, input_width: 3, consolidation_threshold: 4,
    coherence_threshold: 0.06, reuse_threshold: 0.50, edge_retention: 0.9995,
    activity_retention: 0.72, plasticity_fanout: 6, plasticity_budget: 0.08,
    minimum_compression_gain: 2.0, output_plasticity_budget: 0.08,
    output_plasticity_fanout: 8, output_edge_retention: 0.9995]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)

    rows =
      for variant <- @variants, condition <- @conditions, entity <- 1..population do
        run_one(variant, condition, entity, seed, opts)
      end

    %{population: population, rows: rows, summary: summarize(rows, population)}
  end

  def report(result) do
    rows =
      for variant <- @variants, condition <- @conditions do
        s = result.summary[{variant, condition}]

        "#{variant}/#{condition}: survived=#{s.survived}/#{result.population} " <>
          "reached=#{s.reached}/#{result.population} collected=#{s.collected}/#{result.population} " <>
          "returned=#{s.returned}/#{result.population} consumed=#{s.consumed}/#{result.population} " <>
          "contexts=#{fmt(s.contexts)}/4 blocked_repeat=#{fmt(s.blocked_repeat)} " <>
          "useful_repeat=#{fmt(s.useful_repeat)} ticks=#{fmt(s.ticks)}"
      end

    Enum.join([
      "Transition-sensitive home foraging",
      "slow_long_lived: 0.05x motor learning, 10x exposure, gentler physics"
      | rows
    ], "\n")
  end

  defp run_one(variant, condition, entity, seed, run_opts) do
    cfg = config(variant, run_opts)
    total = cfg.stage_ticks * 5 + cfg.withdrawal_ticks

    opts =
      @field_opts
      |> Keyword.put(:encoding_salt, {:contingency, variant, condition, entity})
      |> Keyword.put(:output_learning_scale, cfg.learning_scale)

    initial = %{field: Field.new(opts), position: @home, vitality: cfg.vitality,
      warmth: 1.0, carrying: false, alive?: true, tick: 0, records: [],
      last_move: :none, last_intake: false, caregiver: :none}

    final =
      Enum.reduce_while(1..total, initial, fn tick, prior ->
        stage = stage(tick, cfg.stage_ticks)
        state = reset_withdrawal_carrying(prior, stage, cfg.stage_ticks)
        food = food_cell(stage)
        baseline = max(0.0, state.vitality - cfg.metabolic)
        warmth = update_warmth(state.warmth, state.position, cfg.warmth_loss)
        hunger = 1.0 - baseline
        cold = 1.0 - warmth

        field = Field.sense(state.field, sensory_features(state, food, hunger, warmth, cold), opts)
        sensed = %{state | field: field, warmth: warmth}
        intended = choose(sensed, hunger, cold, tick, seed + entity * 137, opts)
        help = assist(condition, stage, intended, sensed, food, hunger, cold)
        action = help.action

        before_distance = distance(state.position, target(state.carrying, food))
        position = move(state.position, action)
        {carrying, intake, event} = interact(state.carrying, position, food, action, hunger)
        after_distance = distance(position, target(carrying, food))
        movement = movement(action, state.position, position)

        coherence = transition_coherence(action, event, movement, before_distance,
          after_distance, state.position, warmth)
        field = Field.record_output(field, action, coherence, opts)

        cost = action_cost(action, state.position, position, help.level) * cfg.action_scale
        vitality = max(0.0, min(1.0, baseline - cost - cold * cfg.cold_cost + intake))

        record = %{stage: stage, action: action, position: position, food: food,
          carrying: carrying, event: event, intake: intake, movement: movement,
          coherence: coherence}

        next = %{state | field: field, position: position, vitality: vitality,
          warmth: warmth, carrying: carrying, alive?: vitality > 0.0 and warmth > 0.0,
          tick: tick, records: [record | state.records], last_move: movement,
          last_intake: intake > 0.0, caregiver: caregiver_sensation(help.level)}

        if next.alive?, do: {:cont, next}, else: {:halt, next}
      end)

    records = Enum.reverse(final.records)
    withdrawal = Enum.filter(records, &(&1.stage == :withdrawal))

    %{variant: variant, condition: condition, entity: entity,
      survived: final.alive? and final.tick == total, ticks: final.tick,
      reached: Enum.any?(withdrawal, &(&1.position == &1.food)),
      collected: Enum.any?(withdrawal, &(&1.event == :food_collected)),
      returned: returned_after_collection?(withdrawal),
      consumed: Enum.any?(withdrawal, &(&1.event == :food_consumed_at_home)),
      blocked_repeat: repeat_fraction(withdrawal, &(&1.movement == :blocked)),
      useful_repeat: repeat_fraction(withdrawal, &(&1.coherence > 0.0)),
      contexts: context_audit(final.field, opts)}
  end

  defp config(:standard, opts), do: %{stage_ticks: Keyword.get(opts, :standard_stage_ticks, 40),
    withdrawal_ticks: Keyword.get(opts, :standard_withdrawal_ticks, 120), vitality: 0.72,
    metabolic: 0.010, cold_cost: 0.006, warmth_loss: 0.018,
    action_scale: 1.0, learning_scale: 1.0}

  defp config(:slow_long_lived, opts), do: %{stage_ticks: Keyword.get(opts, :slow_stage_ticks, 400),
    withdrawal_ticks: Keyword.get(opts, :slow_withdrawal_ticks, 1_200), vitality: 0.98,
    metabolic: 0.001, cold_cost: 0.0005, warmth_loss: 0.0015,
    action_scale: 0.12, learning_scale: 0.05}

  defp reset_withdrawal_carrying(state, :withdrawal, stage_ticks)
       when state.tick == stage_ticks * 5, do: %{state | carrying: false}
  defp reset_withdrawal_carrying(state, _stage, _stage_ticks), do: state

  defp sensory_features(state, food, hunger, warmth, cold), do: [
    {:body, :hunger, bucket(hunger)}, {:body, :warmth, bucket(warmth)},
    {:body, :cold, bucket(cold)}, {:vision, :home_relation, relation(state.position, @home)},
    {:vision, :home_direction, direction_relation(state.position, @home)},
    {:vision, :food_relation, relation(state.position, food)},
    {:vision, :food_direction, direction_relation(state.position, food)},
    {:touch, :food_contact, state.position == food},
    {:proprioception, :movement, state.last_move}, {:load, :carrying, state.carrying},
    {:taste, :recent_intake, state.last_intake}, {:touch, :caregiver, state.caregiver}]

  defp choose(state, hunger, cold, tick, seed, opts) do
    @actions
    |> Enum.map(fn action ->
      noise = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * 0.20
      learned = Field.output_score(state.field, action, opts) * 0.65
      {action, noise + max(hunger, cold) * 0.22 + learned}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp transition_coherence(_action, :food_collected, _movement, _before, _after, _position, _warmth), do: 1.0
  defp transition_coherence(_action, :food_consumed_at_home, _movement, _before, _after, _position, _warmth), do: 1.0
  defp transition_coherence(action, _event, :blocked, _before, _after, _position, _warmth)
       when action in [:north, :south, :east, :west], do: -1.0
  defp transition_coherence(action, _event, :moved, before_distance, after_distance, _position, _warmth)
       when action in [:north, :south, :east, :west] and after_distance < before_distance, do: 0.8
  defp transition_coherence(action, _event, :moved, before_distance, after_distance, _position, _warmth)
       when action in [:north, :south, :east, :west] and after_distance > before_distance, do: -0.6
  defp transition_coherence(:manipulate, :none, _movement, _before, _after, _position, _warmth), do: -0.7
  defp transition_coherence(:wait, :none, _movement, _before, _after, @home, warmth)
       when warmth < 0.75, do: 0.2
  defp transition_coherence(:wait, :none, _movement, _before, _after, _position, _warmth), do: -0.2
  defp transition_coherence(_action, _event, _movement, _before, _after, _position, _warmth), do: 0.0

  defp context_audit(field, opts) do
    probes = [
      {probe({3, 3}, {3, 3}, false, :moved), :manipulate},
      {probe({3, 3}, {3, 3}, true, :none), :west},
      {probe({0, 2}, {3, 3}, true, :moved), :north},
      {probe(@home, {3, 3}, true, :moved), :manipulate}
    ]

    Enum.count(probes, fn {features, expected} ->
      sensed = Field.sense(field, features, opts)
      winner = Field.output_scores(sensed, @actions, opts)
        |> Enum.max_by(fn {action, score} -> {score, action} end)
        |> elem(0)
      winner == expected
    end)
  end

  defp probe(position, food, carrying, movement), do: [
    {:body, :hunger, :high}, {:body, :warmth, :high}, {:body, :cold, :low},
    {:vision, :home_relation, relation(position, @home)},
    {:vision, :home_direction, direction_relation(position, @home)},
    {:vision, :food_relation, relation(position, food)},
    {:vision, :food_direction, direction_relation(position, food)},
    {:touch, :food_contact, position == food}, {:proprioception, :movement, movement},
    {:load, :carrying, carrying}, {:taste, :recent_intake, false},
    {:touch, :caregiver, :none}]

  defp assist(:abrupt_assistance, stage, _intended, state, food, hunger, cold)
       when stage != :withdrawal and (hunger > 0.34 or cold > 0.30),
       do: %{action: guided_action(state, food), level: 1.0}
  defp assist(:abrupt_assistance, _stage, intended, _state, _food, _hunger, _cold),
    do: %{action: intended, level: 0.0}
  defp assist(:staged_assistance, stage, intended, state, food, hunger, cold)
       when stage != :withdrawal and (hunger > 0.30 or cold > 0.26) do
    target = guided_action(state, food)
    %{action: target, level: assistance_level(stage, intended == target)}
  end
  defp assist(:staged_assistance, _stage, intended, _state, _food, _hunger, _cold),
    do: %{action: intended, level: 0.0}

  defp assistance_level(:full_guidance, _), do: 1.0
  defp assistance_level(:co_produced, true), do: 0.55
  defp assistance_level(:co_produced, false), do: 0.80
  defp assistance_level(:local_independent, true), do: 0.30
  defp assistance_level(:local_independent, false), do: 0.60
  defp assistance_level(:guided_approach, true), do: 0.20
  defp assistance_level(:guided_approach, false), do: 0.45
  defp assistance_level(:near_independent, true), do: 0.10
  defp assistance_level(:near_independent, false), do: 0.30

  defp guided_action(%{carrying: false, position: position}, food) when position == food, do: :manipulate
  defp guided_action(%{carrying: false, position: position}, food), do: direction(position, food)
  defp guided_action(%{carrying: true, position: @home}, _food), do: :manipulate
  defp guided_action(%{carrying: true, position: position}, _food), do: direction(position, @home)

  defp summarize(rows, population) do
    Map.new(for variant <- @variants, condition <- @conditions do
      selected = Enum.filter(rows, &(&1.variant == variant and &1.condition == condition))
      {{variant, condition}, %{population: population,
        survived: Enum.count(selected, & &1.survived), reached: Enum.count(selected, & &1.reached),
        collected: Enum.count(selected, & &1.collected), returned: Enum.count(selected, & &1.returned),
        consumed: Enum.count(selected, & &1.consumed),
        contexts: mean(Enum.map(selected, &(&1.contexts * 1.0))),
        blocked_repeat: mean(Enum.map(selected, & &1.blocked_repeat)),
        useful_repeat: mean(Enum.map(selected, & &1.useful_repeat)),
        ticks: median(Enum.map(selected, &(&1.ticks * 1.0)))}}
    end)
  end

  defp returned_after_collection?(records) do
    case Enum.find_index(records, &(&1.event == :food_collected)) do
      nil -> false
      index -> records |> Enum.drop(index + 1) |> Enum.any?(&(&1.carrying and &1.position == @home))
    end
  end

  defp repeat_fraction(records, predicate) do
    pairs = Enum.chunk_every(records, 2, 1, :discard)
    count = Enum.count(pairs, fn [first, second] -> predicate.(first) and first.action == second.action end)
    if pairs == [], do: 0.0, else: count / length(pairs)
  end

  defp stage(tick, width) when tick <= width, do: :full_guidance
  defp stage(tick, width) when tick <= width * 2, do: :co_produced
  defp stage(tick, width) when tick <= width * 3, do: :local_independent
  defp stage(tick, width) when tick <= width * 4, do: :guided_approach
  defp stage(tick, width) when tick <= width * 5, do: :near_independent
  defp stage(_tick, _width), do: :withdrawal
  defp food_cell(stage) when stage in [:full_guidance, :co_produced], do: {3, 0}
  defp food_cell(stage) when stage in [:local_independent, :guided_approach], do: {3, 2}
  defp food_cell(:near_independent), do: {2, 3}
  defp food_cell(:withdrawal), do: {3, 3}
  defp target(false, food), do: food
  defp target(true, _food), do: @home
  defp distance({x, y}, {tx, ty}), do: abs(x - tx) + abs(y - ty)
  defp relation(position, position), do: :contact
  defp relation({x, y}, {tx, ty}) when abs(x - tx) + abs(y - ty) == 1, do: :adjacent
  defp relation(_position, _target), do: :distant

  defp direction_relation(position, position), do: :here
  defp direction_relation({x, y}, {tx, ty}) do
    vertical = cond do y > ty -> "north"; y < ty -> "south"; true -> nil end
    horizontal = cond do x > tx -> "west"; x < tx -> "east"; true -> nil end
    [vertical, horizontal] |> Enum.reject(&is_nil/1) |> Enum.join("_") |> String.to_atom()
  end

  defp direction({x, _y}, {tx, _ty}) when x < tx, do: :east
  defp direction({x, _y}, {tx, _ty}) when x > tx, do: :west
  defp direction({_x, y}, {_tx, ty}) when y < ty, do: :south
  defp direction({_x, y}, {_tx, ty}) when y > ty, do: :north
  defp direction(position, position), do: :wait
  defp move(position, action) when action in [:manipulate, :wait], do: position
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp movement(action, position, position) when action in [:north, :south, :east, :west], do: :blocked
  defp movement(action, _before, _after) when action in [:north, :south, :east, :west], do: :moved
  defp movement(_action, _before, _after), do: :none
  defp interact(false, position, position, :manipulate, _hunger), do: {true, 0.0, :food_collected}
  defp interact(true, @home, _food, :manipulate, hunger), do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}
  defp interact(carrying, _position, _food, _action, _hunger), do: {carrying, 0.0, :none}
  defp update_warmth(warmth, @home, _loss), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _position, loss), do: max(0.0, warmth - loss)
  defp action_cost(:wait, _before, _after, level), do: 0.002 * effort(level)
  defp action_cost(:manipulate, _before, _after, level), do: 0.004 * effort(level)
  defp action_cost(_action, position, position, level), do: 0.008 * effort(level)
  defp action_cost(_action, _before, _after, level), do: 0.010 * effort(level)
  defp effort(level), do: max(0.25, 1.0 - level * 0.75)
  defp caregiver_sensation(level) when level <= 0.0, do: :none
  defp caregiver_sensation(level) when level < 0.5, do: :light
  defp caregiver_sensation(_level), do: :strong
  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_value), do: :very_high
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)
    if rem(length(sorted), 2) == 1,
      do: Enum.at(sorted, middle),
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
