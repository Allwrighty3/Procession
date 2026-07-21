defmodule Procession.Simulation.HomeForagingContingencyExperiment do
  @moduledoc "Transition-sensitive home-foraging with a slow, long-lived learner variant."
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
    pop = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)
    rows = for v <- @variants, c <- @conditions, e <- 1..pop, do: one(v, c, e, seed, opts)
    %{population: pop, rows: rows, summary: summarize(rows, pop)}
  end

  def report(r) do
    lines = for v <- @variants, c <- @conditions do
      s = r.summary[{v, c}]
      "#{v}/#{c}: survived=#{s.survived}/#{r.population} reached=#{s.reached}/#{r.population} " <>
        "collected=#{s.collected}/#{r.population} returned=#{s.returned}/#{r.population} " <>
        "consumed=#{s.consumed}/#{r.population} contexts=#{fmt(s.contexts)}/4 " <>
        "blocked_repeat=#{fmt(s.blocked_repeat)} useful_repeat=#{fmt(s.useful_repeat)} ticks=#{fmt(s.ticks)}"
    end
    Enum.join(["Transition-sensitive home foraging",
      "slow_long_lived: 0.05x motor learning, 10x exposure, gentler physics" | lines], "\n")
  end

  defp one(variant, condition, entity, seed, run_opts) do
    cfg = config(variant, run_opts)
    total = cfg.width * 5 + cfg.withdrawal
    opts = @field_opts
      |> Keyword.put(:encoding_salt, {:contingency, variant, condition, entity})
      |> Keyword.put(:output_learning_scale, cfg.learning)
    initial = %{field: Field.new(opts), position: @home, vitality: cfg.vitality, warmth: 1.0,
      carrying: false, alive?: true, tick: 0, records: [], last_move: :none,
      last_intake: false, caregiver: :none}

    final = Enum.reduce_while(1..total, initial, fn tick, prior ->
      stage = stage(tick, cfg.width)
      state = if stage == :withdrawal and prior.tick == cfg.width * 5,
        do: %{prior | carrying: false}, else: prior
      food = food(stage)
      base = max(0.0, state.vitality - cfg.metabolic)
      warmth = warm(state.warmth, state.position, cfg)
      hunger = 1.0 - base
      cold = 1.0 - warmth
      field = Field.sense(state.field, senses(state, food, hunger, warmth, cold), opts)
      sensed = %{state | field: field, warmth: warmth}
      intended = choose(sensed, hunger, cold, tick, seed + entity * 137, opts)
      help = assist(condition, stage, intended, sensed, food, hunger, cold)
      action = help.action
      before_d = distance(state.position, target(state.carrying, food))
      position = move(state.position, action)
      {carrying, intake, event} = interact(state.carrying, position, food, action, hunger)
      after_d = distance(position, target(carrying, food))
      movement = movement(action, state.position, position)
      coherence = coherence(action, event, movement, before_d, after_d, state.position, warmth)
      field = Field.record_output(field, action, coherence, opts)
      vitality = max(0.0, min(1.0, base - action_cost(action, state.position, position, help.level) * cfg.cost_scale - cold * cfg.cold_cost + intake))
      rec = %{stage: stage, action: action, position: position, food: food, carrying: carrying,
        event: event, intake: intake, movement: movement, coherence: coherence}
      next = %{state | field: field, position: position, vitality: vitality, warmth: warmth,
        carrying: carrying, alive?: vitality > 0.0 and warmth > 0.0, tick: tick,
        records: [rec | state.records], last_move: movement, last_intake: intake > 0.0,
        caregiver: caregiver(help.level)}
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)

    records = Enum.reverse(final.records)
    withdrawal = Enum.filter(records, &(&1.stage == :withdrawal))
    %{variant: variant, condition: condition, entity: entity,
      survived: final.alive? and final.tick == total, ticks: final.tick,
      reached: Enum.any?(withdrawal, &(&1.position == &1.food)),
      collected: Enum.any?(withdrawal, &(&1.event == :food_collected)),
      returned: returned?(withdrawal),
      consumed: Enum.any?(withdrawal, &(&1.event == :food_consumed_at_home)),
      blocked_repeat: repeat_fraction(withdrawal, fn r -> r.movement == :blocked end),
      useful_repeat: repeat_fraction(withdrawal, fn r -> r.coherence > 0.0 end),
      contexts: audit(final.field, opts)}
  end

  defp config(:standard, o), do: %{width: Keyword.get(o, :standard_stage_ticks, 40),
    withdrawal: Keyword.get(o, :standard_withdrawal_ticks, 120), vitality: 0.72,
    metabolic: 0.010, cold_cost: 0.006, warmth_loss: 0.018, cost_scale: 1.0, learning: 1.0}
  defp config(:slow_long_lived, o), do: %{width: Keyword.get(o, :slow_stage_ticks, 400),
    withdrawal: Keyword.get(o, :slow_withdrawal_ticks, 1_200), vitality: 0.98,
    metabolic: 0.001, cold_cost: 0.0005, warmth_loss: 0.0015, cost_scale: 0.12, learning: 0.05}

  defp senses(s, food, hunger, warmth, cold), do: [
    {:body, :hunger, bucket(hunger)}, {:body, :warmth, bucket(warmth)},
    {:body, :cold, bucket(cold)}, {:vision, :home_relation, relation(s.position, @home)},
    {:vision, :home_direction, direction_relation(s.position, @home)},
    {:vision, :food_relation, relation(s.position, food)},
    {:vision, :food_direction, direction_relation(s.position, food)},
    {:touch, :food_contact, s.position == food}, {:proprioception, :movement, s.last_move},
    {:load, :carrying, s.carrying}, {:taste, :recent_intake, s.last_intake},
    {:touch, :caregiver, s.caregiver}]

  defp choose(s, hunger, cold, tick, seed, opts) do
    @actions |> Enum.map(fn a ->
      noise = :erlang.phash2({seed, tick, a}, 1_000) / 1_000 * 0.20
      {a, noise + max(hunger, cold) * 0.22 + Field.output_score(s.field, a, opts) * 0.65}
    end) |> Enum.max_by(fn {a, score} -> {score, a} end) |> elem(0)
  end

  defp coherence(_, :food_collected, _, _, _, _, _), do: 1.0
  defp coherence(_, :food_consumed_at_home, _, _, _, _, _), do: 1.0
  defp coherence(a, _, :blocked, _, _, _, _) when a in [:north, :south, :east, :west], do: -1.0
  defp coherence(a, _, :moved, before, after_d, _, _) when a in [:north, :south, :east, :west] and after_d < before, do: 0.8
  defp coherence(a, _, :moved, before, after_d, _, _) when a in [:north, :south, :east, :west] and after_d > before, do: -0.6
  defp coherence(:manipulate, :none, _, _, _, _, _), do: -0.7
  defp coherence(:wait, :none, _, _, _, @home, warmth) when warmth < 0.75, do: 0.2
  defp coherence(:wait, :none, _, _, _, _, _), do: -0.2
  defp coherence(_, _, _, _, _, _, _), do: 0.0

  defp audit(field, opts) do
    probes = [
      {probe({3, 3}, {3, 3}, false, :moved), :manipulate},
      {probe({3, 3}, {3, 3}, true, :none), :west},
      {probe({0, 2}, {3, 3}, true, :moved), :north},
      {probe(@home, {3, 3}, true, :moved), :manipulate}]
    Enum.count(probes, fn {features, expected} ->
      sensed = Field.sense(field, features, opts)
      winner = Field.output_scores(sensed, @actions, opts)
        |> Enum.max_by(fn {a, score} -> {score, a} end) |> elem(0)
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
    {:load, :carrying, carrying}, {:taste, :recent_intake, false}, {:touch, :caregiver, :none}]

  defp assist(:abrupt_assistance, stage, _, s, food, hunger, cold)
       when stage != :withdrawal and (hunger > 0.34 or cold > 0.30), do: help(guided(s, food), 1.0)
  defp assist(:abrupt_assistance, _, intended, _, _, _, _), do: help(intended, 0.0)
  defp assist(:staged_assistance, stage, intended, s, food, hunger, cold)
       when stage != :withdrawal and (hunger > 0.30 or cold > 0.26) do
    target = guided(s, food); help(target, level(stage, intended == target))
  end
  defp assist(:staged_assistance, _, intended, _, _, _, _), do: help(intended, 0.0)
  defp level(:full_guidance, _), do: 1.0
  defp level(:co_produced, true), do: 0.55
  defp level(:co_produced, false), do: 0.80
  defp level(:local_independent, true), do: 0.30
  defp level(:local_independent, false), do: 0.60
  defp level(:guided_approach, true), do: 0.20
  defp level(:guided_approach, false), do: 0.45
  defp level(:near_independent, true), do: 0.10
  defp level(:near_independent, false), do: 0.30
  defp guided(%{carrying: false, position: p}, food) when p == food, do: :manipulate
  defp guided(%{carrying: false, position: p}, food), do: direction(p, food)
  defp guided(%{carrying: true, position: @home}, _), do: :manipulate
  defp guided(%{carrying: true, position: p}, _), do: direction(p, @home)
  defp help(action, level), do: %{action: action, level: level}

  defp summarize(rows, pop), do: Map.new(for v <- @variants, c <- @conditions do
    rs = Enum.filter(rows, &(&1.variant == v and &1.condition == c))
    {{v, c}, %{population: pop, survived: Enum.count(rs, & &1.survived),
      reached: Enum.count(rs, & &1.reached), collected: Enum.count(rs, & &1.collected),
      returned: Enum.count(rs, & &1.returned), consumed: Enum.count(rs, & &1.consumed),
      contexts: mean(Enum.map(rs, &(&1.contexts * 1.0))),
      blocked_repeat: mean(Enum.map(rs, & &1.blocked_repeat)),
      useful_repeat: mean(Enum.map(rs, & &1.useful_repeat)), ticks: median(Enum.map(rs, &(&1.ticks * 1.0)))}}
  end)

  defp returned?(records), do: case Enum.find_index(records, &(&1.event == :food_collected)) do
    nil -> false
    i -> records |> Enum.drop(i + 1) |> Enum.any?(&(&1.carrying and &1.position == @home))
  end
  defp repeat_fraction(records, predicate) do
    pairs = Enum.chunk_every(records, 2, 1, :discard)
    n = Enum.count(pairs, fn [a, b] -> predicate.(a) and a.action == b.action end)
    if pairs == [], do: 0.0, else: n / length(pairs)
  end

  defp stage(t, w) when t <= w, do: :full_guidance
  defp stage(t, w) when t <= w * 2, do: :co_produced
  defp stage(t, w) when t <= w * 3, do: :local_independent
  defp stage(t, w) when t <= w * 4, do: :guided_approach
  defp stage(t, w) when t <= w * 5, do: :near_independent
  defp stage(_, _), do: :withdrawal
  defp food(s) when s in [:full_guidance, :co_produced], do: {3, 0}
  defp food(s) when s in [:local_independent, :guided_approach], do: {3, 2}
  defp food(:near_independent), do: {2, 3}
  defp food(:withdrawal), do: {3, 3}
  defp target(false, food), do: food
  defp target(true, _), do: @home
  defp distance({x, y}, {tx, ty}), do: abs(x - tx) + abs(y - ty)
  defp relation(p, p), do: :contact
  defp relation({x, y}, {tx, ty}) when abs(x - tx) + abs(y - ty) == 1, do: :adjacent
  defp relation(_, _), do: :distant
  defp direction_relation(p, p), do: :here
  defp direction_relation({x, y}, {tx, ty}) do
    v = cond do y > ty -> "north"; y < ty -> "south"; true -> nil end
    h = cond do x > tx -> "west"; x < tx -> "east"; true -> nil end
    [v, h] |> Enum.reject(&is_nil/1) |> Enum.join("_") |> String.to_atom()
  end
  defp direction({x, _}, {tx, _}) when x < tx, do: :east
  defp direction({x, _}, {tx, _}) when x > tx, do: :west
  defp direction({_, y}, {_, ty}) when y < ty, do: :south
  defp direction({_, y}, {_, ty}) when y > ty, do: :north
  defp direction(p, p), do: :wait
  defp move(p, a) when a in [:manipulate, :wait], do: p
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp movement(a, p, p) when a in [:north, :south, :east, :west], do: :blocked
  defp movement(a, _, _) when a in [:north, :south, :east, :west], do: :moved
  defp movement(_, _, _), do: :none
  defp interact(false, p, p, :manipulate, _), do: {true, 0.0, :food_collected}
  defp interact(true, @home, _, :manipulate, h), do: {false, min(0.34, 0.18 + h * 0.22), :food_consumed_at_home}
  defp interact(c, _, _, _, _), do: {c, 0.0, :none}
  defp warm(w, @home, _), do: min(1.0, w + 0.12)
  defp warm(w, _, cfg), do: max(0.0, w - cfg.warmth_loss)
  defp action_cost(:wait, _, _, l), do: 0.002 * effort(l)
  defp action_cost(:manipulate, _, _, l), do: 0.004 * effort(l)
  defp action_cost(_, p, p, l), do: 0.008 * effort(l)
  defp action_cost(_, _, _, l), do: 0.010 * effort(l)
  defp effort(l), do: max(0.25, 1.0 - l * 0.75)
  defp caregiver(l) when l <= 0.0, do: :none
  defp caregiver(l) when l < 0.5, do: :light
  defp caregiver(_), do: :strong
  defp bucket(v) when v < 0.25, do: :very_low
  defp bucket(v) when v < 0.50, do: :low
  defp bucket(v) when v < 0.75, do: :high
  defp bucket(_), do: :very_high
  defp mean([]), do: 0.0
  defp mean(v), do: Enum.sum(v) / length(v)
  defp median([]), do: 0.0
  defp median(v) do s = Enum.sort(v); m = div(length(s), 2); if rem(length(s), 2) == 1, do: Enum.at(s, m), else: (Enum.at(s, m - 1) + Enum.at(s, m)) / 2 end
  defp fmt(v), do: :erlang.float_to_binary(v * 1.0, decimals: 3)
end
