defmodule Procession.Simulation.HomeForagingPressureControlExperiment do
  @moduledoc "Ultra-slow home-foraging under restored pressure and no-teacher control."

  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @actions [:manipulate, :wait, :north, :south, :east, :west]
  @home {0, 0}
  @field_opts [micro_nodes: 64, input_width: 3, consolidation_threshold: 4,
    coherence_threshold: 0.06, reuse_threshold: 0.50, edge_retention: 0.9995,
    activity_retention: 0.72, plasticity_fanout: 6, plasticity_budget: 0.08,
    minimum_compression_gain: 2.0, output_plasticity_budget: 0.08,
    output_plasticity_fanout: 8, output_edge_retention: 0.9995,
    output_learning_scale: 0.01]

  @profiles %{
    ultra_forgiving: %{vitality: 0.995, metabolic: 0.00035, cold: 0.00015,
      warmth_loss: 0.0005, action_scale: 0.04},
    moderate_pressure: %{vitality: 0.99, metabolic: 0.00065, cold: 0.00030,
      warmth_loss: 0.0009, action_scale: 0.075},
    slow_pressure: %{vitality: 0.98, metabolic: 0.0010, cold: 0.0005,
      warmth_loss: 0.0015, action_scale: 0.12},
    full_pressure: %{vitality: 0.72, metabolic: 0.010, cold: 0.006,
      warmth_loss: 0.018, action_scale: 1.0}
  }

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)
    stage_ticks = Keyword.get(opts, :stage_ticks, 1_000)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 3_000)

    taught =
      for profile <- Map.keys(@profiles),
          condition <- [:abrupt_assistance, :staged_assistance],
          entity <- 1..population do
        run_one(profile, condition, entity, seed, stage_ticks, withdrawal_ticks)
      end

    control =
      for entity <- 1..population do
        run_one(:ultra_forgiving, :no_teacher, entity, seed, stage_ticks, withdrawal_ticks)
      end

    rows = taught ++ control
    %{population: population, rows: rows, summary: summarize(rows)}
  end

  def report(result) do
    taught =
      for profile <- Map.keys(@profiles),
          condition <- [:abrupt_assistance, :staged_assistance] do
        format_line(profile, condition, result.summary[{profile, condition}], result.population)
      end

    control =
      format_line(:ultra_forgiving, :no_teacher,
        result.summary[{:ultra_forgiving, :no_teacher}], result.population)

    Enum.join([
      "Ultra-slow home-foraging pressure ladder",
      "all cohorts use 0.01x motor learning and identical 8000-tick schedules",
      "no_teacher differs from ultra_forgiving taught cohorts only by assistance"
      | taught ++ [control]
    ], "\n")
  end

  defp format_line(profile, condition, s, population) do
    "#{profile}/#{condition}: survived=#{s.survived}/#{population} " <>
      "consumed=#{s.consumed}/#{population} repeaters=#{s.repeaters}/#{population} " <>
      "cycles=#{fmt(s.cycles)} first=#{fmt(s.first_cycle)} gap=#{fmt(s.gap)} " <>
      "collections=#{fmt(s.collections)} unclosed=#{fmt(s.unclosed)} " <>
      "blocked=#{fmt(s.blocked)} entropy=#{fmt(s.entropy)} ticks=#{fmt(s.ticks)}"
  end

  defp run_one(profile, condition, entity, seed, stage_ticks, withdrawal_ticks) do
    cfg = Map.fetch!(@profiles, profile)
    total = stage_ticks * 5 + withdrawal_ticks
    opts = Keyword.put(@field_opts, :encoding_salt,
      {:pressure_control, profile, condition, seed, entity})

    initial = %{field: Field.new(opts), position: @home, vitality: cfg.vitality,
      warmth: 1.0, carrying: false, alive?: true, tick: 0, records: [],
      last_move: :none, last_intake: false, caregiver: :none}

    final =
      Enum.reduce_while(1..total, initial, fn tick, prior ->
        stage = stage(tick, stage_ticks)
        state =
          if stage == :withdrawal and prior.tick == stage_ticks * 5,
            do: %{prior | carrying: false}, else: prior

        food = food_cell(stage)
        baseline = max(0.0, state.vitality - cfg.metabolic)
        warmth = update_warmth(state.warmth, state.position, cfg.warmth_loss)
        hunger = 1.0 - baseline
        cold = 1.0 - warmth
        field = Field.sense(state.field, features(state, food, hunger, warmth, cold), opts)
        sensed = %{state | field: field, warmth: warmth}
        intended = choose(sensed, hunger, cold, tick, seed + entity * 137, opts)
        help = assist(condition, stage, intended, sensed, food, hunger, cold)
        action = help.action
        before_distance = distance(state.position, target(state.carrying, food))
        position = move(state.position, action)
        {carrying, intake, event} = interact(state.carrying, position, food, action, hunger)
        after_distance = distance(position, target(carrying, food))
        movement = movement(action, state.position, position)
        signal = coherence(action, event, movement, before_distance, after_distance,
          state.position, warmth)
        field = Field.record_output(field, action, signal, opts)
        cost = action_cost(action, state.position, position, help.level) * cfg.action_scale
        vitality = max(0.0, min(1.0, baseline - cost - cold * cfg.cold + intake))
        record = %{tick: tick, stage: stage, action: action, position: position,
          food: food, event: event, movement: movement}
        next = %{state | field: field, position: position, vitality: vitality,
          warmth: warmth, carrying: carrying, alive?: vitality > 0.0 and warmth > 0.0,
          tick: tick, records: [record | state.records], last_move: movement,
          last_intake: intake > 0.0, caregiver: caregiver(help.level)}

        if next.alive?, do: {:cont, next}, else: {:halt, next}
      end)

    withdrawal = final.records |> Enum.reverse() |> Enum.filter(&(&1.stage == :withdrawal))
    cycle_ticks = for r <- withdrawal, r.event == :food_consumed_at_home, do: r.tick
    collections = Enum.count(withdrawal, &(&1.event == :food_collected))

    %{profile: profile, condition: condition, entity: entity,
      survived: final.alive? and final.tick == total, ticks: final.tick,
      consumed: cycle_ticks != [], repeated: length(cycle_ticks) >= 2,
      cycles: length(cycle_ticks), first_cycle: first_or_zero(cycle_ticks),
      gap: median_gaps(cycle_ticks), collections: collections,
      unclosed: max(0, collections - length(cycle_ticks)),
      blocked: repeat_fraction(withdrawal, &(&1.movement == :blocked)),
      entropy: entropy(withdrawal)}
  end

  defp summarize(rows) do
    rows
    |> Enum.group_by(&{&1.profile, &1.condition})
    |> Map.new(fn {key, selected} ->
      {key, %{
        survived: Enum.count(selected, & &1.survived),
        consumed: Enum.count(selected, & &1.consumed),
        repeaters: Enum.count(selected, & &1.repeated),
        cycles: mean(Enum.map(selected, &(&1.cycles * 1.0))),
        first_cycle: positive_median(Enum.map(selected, &(&1.first_cycle * 1.0))),
        gap: positive_median(Enum.map(selected, &(&1.gap * 1.0))),
        collections: mean(Enum.map(selected, &(&1.collections * 1.0))),
        unclosed: mean(Enum.map(selected, &(&1.unclosed * 1.0))),
        blocked: mean(Enum.map(selected, & &1.blocked)),
        entropy: mean(Enum.map(selected, & &1.entropy)),
        ticks: median(Enum.map(selected, &(&1.ticks * 1.0)))
      }}
    end)
  end

  defp features(state, food, hunger, warmth, cold), do: [
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

  defp assist(:no_teacher, _stage, intended, _state, _food, _hunger, _cold),
    do: %{action: intended, level: 0.0}
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

  defp guided_action(%{carrying: false, position: p}, food) when p == food, do: :manipulate
  defp guided_action(%{carrying: false, position: p}, food), do: direction(p, food)
  defp guided_action(%{carrying: true, position: @home}, _food), do: :manipulate
  defp guided_action(%{carrying: true, position: p}, _food), do: direction(p, @home)

  defp coherence(_, :food_collected, _, _, _, _, _), do: 1.0
  defp coherence(_, :food_consumed_at_home, _, _, _, _, _), do: 1.0
  defp coherence(a, _, :blocked, _, _, _, _) when a in [:north, :south, :east, :west], do: -1.0
  defp coherence(a, _, :moved, before, after_, _, _)
       when a in [:north, :south, :east, :west] and after_ < before, do: 0.8
  defp coherence(a, _, :moved, before, after_, _, _)
       when a in [:north, :south, :east, :west] and after_ > before, do: -0.6
  defp coherence(:manipulate, :none, _, _, _, _, _), do: -0.7
  defp coherence(:wait, :none, _, _, _, @home, warmth) when warmth < 0.75, do: 0.2
  defp coherence(:wait, :none, _, _, _, _, _), do: -0.2
  defp coherence(_, _, _, _, _, _, _), do: 0.0

  defp stage(tick, width) when tick <= width, do: :full_guidance
  defp stage(tick, width) when tick <= width * 2, do: :co_produced
  defp stage(tick, width) when tick <= width * 3, do: :local_independent
  defp stage(tick, width) when tick <= width * 4, do: :guided_approach
  defp stage(tick, width) when tick <= width * 5, do: :near_independent
  defp stage(_, _), do: :withdrawal
  defp food_cell(stage) when stage in [:full_guidance, :co_produced], do: {3, 0}
  defp food_cell(stage) when stage in [:local_independent, :guided_approach], do: {3, 2}
  defp food_cell(:near_independent), do: {2, 3}
  defp food_cell(:withdrawal), do: {3, 3}
  defp target(false, food), do: food
  defp target(true, _food), do: @home
  defp distance({x, y}, {tx, ty}), do: abs(x - tx) + abs(y - ty)
  defp relation(position, position), do: :contact
  defp relation({x, y}, {tx, ty}) when abs(x - tx) + abs(y - ty) == 1, do: :adjacent
  defp relation(_, _), do: :distant

  defp direction_relation(position, position), do: :here
  defp direction_relation({x, y}, {tx, ty}) do
    vertical = cond do y > ty -> "north"; y < ty -> "south"; true -> nil end
    horizontal = cond do x > tx -> "west"; x < tx -> "east"; true -> nil end
    [vertical, horizontal] |> Enum.reject(&is_nil/1) |> Enum.join("_") |> String.to_atom()
  end

  defp direction({x, _}, {tx, _}) when x < tx, do: :east
  defp direction({x, _}, {tx, _}) when x > tx, do: :west
  defp direction({_, y}, {_, ty}) when y < ty, do: :south
  defp direction({_, y}, {_, ty}) when y > ty, do: :north
  defp direction(position, position), do: :wait
  defp move(position, action) when action in [:manipulate, :wait], do: position
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp movement(action, p, p) when action in [:north, :south, :east, :west], do: :blocked
  defp movement(action, _, _) when action in [:north, :south, :east, :west], do: :moved
  defp movement(_, _, _), do: :none
  defp interact(false, p, p, :manipulate, _), do: {true, 0.0, :food_collected}
  defp interact(true, @home, _, :manipulate, hunger),
    do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}
  defp interact(carrying, _, _, _, _), do: {carrying, 0.0, :none}
  defp update_warmth(warmth, @home, _), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _, loss), do: max(0.0, warmth - loss)
  defp action_cost(:wait, _, _, level), do: 0.002 * effort(level)
  defp action_cost(:manipulate, _, _, level), do: 0.004 * effort(level)
  defp action_cost(_, p, p, level), do: 0.008 * effort(level)
  defp action_cost(_, _, _, level), do: 0.010 * effort(level)
  defp effort(level), do: max(0.25, 1.0 - level * 0.75)
  defp caregiver(level) when level <= 0.0, do: :none
  defp caregiver(level) when level < 0.5, do: :light
  defp caregiver(_), do: :strong
  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_), do: :very_high

  defp repeat_fraction(records, predicate) do
    pairs = Enum.chunk_every(records, 2, 1, :discard)
    repeats = Enum.count(pairs, fn [a, b] -> predicate.(a) and a.action == b.action end)
    if pairs == [], do: 0.0, else: repeats / length(pairs)
  end

  defp entropy([]), do: 0.0
  defp entropy(records) do
    total = length(records) * 1.0
    records
    |> Enum.frequencies_by(& &1.action)
    |> Enum.reduce(0.0, fn {_action, count}, acc ->
      p = count / total
      acc - p * (:math.log(p) / :math.log(2.0))
    end)
  end

  defp first_or_zero([]), do: 0
  defp first_or_zero([first | _]), do: first
  defp median_gaps([]), do: 0.0
  defp median_gaps([_]), do: 0.0
  defp median_gaps(ticks), do: ticks |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> (b - a) * 1.0 end) |> median()
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
  defp positive_median(values), do: values |> Enum.filter(&(&1 > 0.0)) |> median()
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
