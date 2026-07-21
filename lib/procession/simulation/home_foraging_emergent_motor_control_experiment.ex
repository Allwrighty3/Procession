defmodule Procession.Simulation.HomeForagingEmergentMotorControlExperiment do
  @moduledoc "Matched no-teacher and taught cohorts where movement itself must emerge."

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body

  @conditions [:no_teacher, :taught]
  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)
    max_ticks = Keyword.get(opts, :max_ticks, 320)
    teaching_ticks = min(Keyword.get(opts, :teaching_ticks, 240), max_ticks)

    rows =
      for condition <- @conditions,
          entity <- 1..population do
        run_one(condition, entity, seed, max_ticks, teaching_ticks, opts)
      end

    %{
      population: population,
      max_ticks: max_ticks,
      teaching_ticks: teaching_ticks,
      rows: rows,
      summary: summarize(rows)
    }
  end

  def report(result) do
    lines =
      Enum.map(@conditions, fn condition ->
        summary = result.summary[condition]

        "#{condition}: survived=#{summary.survived}/#{result.population} " <>
          "survived_withdrawal=#{summary.survived_withdrawal}/#{result.population} " <>
          "death=#{fmt(summary.median_death_tick)} displaced=#{summary.displaced}/#{result.population} " <>
          "food=#{summary.reached_food}/#{result.population} collected=#{summary.collected}/#{result.population} " <>
          "home=#{summary.returned_home}/#{result.population} consumed=#{summary.consumed}/#{result.population} " <>
          "stable=#{fmt(summary.stable_patterns)} rate=#{fmt(summary.displacement_rate)} " <>
          "coordination=#{fmt(summary.strongest_coordination)} assistance=#{fmt(summary.assistance_rate)}"
      end)

    Enum.join([
      "Emergent-movement taught comparison",
      "paired seeds and bodies; learner emits every motor pattern",
      "caregiver supports consequences through tick #{result.teaching_ticks}; no mature action is substituted",
      "population=#{result.population} max_ticks=#{result.max_ticks}"
      | lines
    ], "\n")
  end

  defp run_one(condition, entity, seed, max_ticks, teaching_ticks, opts) do
    initial = %{
      body: Body.new(),
      position: @home,
      vitality: Keyword.get(opts, :vitality, 0.72),
      warmth: 1.0,
      carrying: false,
      alive?: true,
      tick: 0,
      last_pattern: nil,
      contact_repeat: 0,
      repertoire: %{},
      records: []
    }

    final =
      Enum.reduce_while(1..max_ticks, initial, fn tick, state ->
        baseline = max(0.0, state.vitality - Keyword.get(opts, :metabolic, 0.010))
        warmth =
          update_warmth(
            state.warmth,
            state.position,
            Keyword.get(opts, :warmth_loss, 0.018)
          )

        cold = 1.0 - warmth
        hunger = 1.0 - baseline
        goal = physical_goal(state)
        teaching? = condition == :taught and tick <= teaching_ticks
        {pattern, repertoire} = select_pattern(state, goal, tick, seed, entity, teaching?)

        {attempted_body, natural_outcome} =
          Body.attempt(
            state.body,
            pattern,
            state.position,
            tick,
            seed: seed + entity * 1_003,
            bounds: @bounds
          )

        {body, outcome, position, assisted?} =
          support_consequence(
            attempted_body,
            natural_outcome,
            state.position,
            pattern,
            goal,
            teaching?
          )

        repeat = contact_repeat(state, pattern, position, outcome)
        {carrying, intake, event} = interact(state.carrying, position, outcome, repeat, hunger)
        effort_scale = if assisted?, do: 0.25, else: 1.0
        cost = motor_cost(outcome) * Keyword.get(opts, :action_scale, 1.0) * effort_scale
        vitality =
          max(
            0.0,
            min(1.0, baseline - cost - cold * Keyword.get(opts, :cold_cost, 0.006) + intake)
          )

        record = %{
          tick: tick,
          phase: if(tick <= teaching_ticks, do: :development, else: :withdrawal),
          pattern: pattern,
          displaced?: outcome.displaced?,
          position: position,
          food_contact?: position == @food,
          event: event,
          carrying: carrying,
          coordination: outcome.coordination,
          assisted?: assisted?
        }

        next = %{
          state
          | body: body,
            position: position,
            vitality: vitality,
            warmth: warmth,
            carrying: carrying,
            alive?: vitality > 0.0 and warmth > 0.0,
            tick: tick,
            last_pattern: pattern,
            contact_repeat: repeat,
            repertoire: repertoire,
            records: [record | state.records]
        }

        if next.alive?, do: {:cont, next}, else: {:halt, next}
      end)

    records = Enum.reverse(final.records)
    strongest = strongest_coordination(final.body)

    %{
      condition: condition,
      entity: entity,
      survived: final.alive? and final.tick == max_ticks,
      survived_withdrawal: final.tick > teaching_ticks,
      death_tick: final.tick,
      displaced: Enum.any?(records, & &1.displaced?),
      first_displacement: first_tick(records, & &1.displaced?),
      reached_food: Enum.any?(records, & &1.food_contact?),
      collected: Enum.any?(records, &(&1.event == :food_collected)),
      returned_home: returned_home?(records),
      consumed: Enum.any?(records, &(&1.event == :food_consumed_at_home)),
      stable_patterns: Body.stable_pattern_count(final.body),
      displacement_rate: fraction(records, & &1.displaced?),
      assistance_rate: fraction(records, & &1.assisted?),
      contact_attempts: Enum.count(records, &(&1.food_contact? and not &1.displaced?)),
      strongest_coordination: strongest
    }
  end

  defp physical_goal(%{carrying: false, position: @food}), do: :contact
  defp physical_goal(%{carrying: false, position: position}), do: direction(position, @food)
  defp physical_goal(%{carrying: true, position: @home}), do: :contact
  defp physical_goal(%{carrying: true, position: position}), do: direction(position, @home)

  defp select_pattern(state, goal, tick, seed, entity, true) do
    case Map.fetch(state.repertoire, goal) do
      {:ok, pattern} -> {pattern, state.repertoire}
      :error ->
        pattern = Body.choose_pattern(state.body, tick, seed + entity * 149)
        {pattern, Map.put(state.repertoire, goal, pattern)}
    end
  end

  defp select_pattern(state, _goal, tick, seed, entity, false) do
    {Body.choose_pattern(state.body, tick, seed + entity * 149), state.repertoire}
  end

  defp support_consequence(body, natural, position, _pattern, _goal, false),
    do: {body, natural, Body.apply_displacement(position, natural), false}

  defp support_consequence(body, natural, position, pattern, :contact, true) do
    body = Body.supported_stability(body, pattern, 1.0)
    coordination = pattern_coordination(body, pattern)

    outcome = %{
      natural
      | direction: :none,
        displaced?: false,
        blocked?: false,
        coordination: coordination,
        consequence: :supported_stability
    }

    {body, outcome, position, true}
  end

  defp support_consequence(body, natural, position, pattern, direction, true) do
    body = Body.supported_attempt(body, pattern, direction, 1.0)
    coordination = pattern_coordination(body, pattern)

    outcome = %{
      natural
      | direction: direction,
        displaced?: true,
        blocked?: false,
        coordination: coordination,
        consequence: :supported_displacement
    }

    {body, outcome, move(position, direction), true}
  end

  defp pattern_coordination(body, pattern) do
    body
    |> Body.strongest_patterns(length(Body.patterns()))
    |> Map.new()
    |> Map.fetch!(pattern)
  end

  defp contact_repeat(state, pattern, position, %{displaced?: false})
       when position in [@food, @home] do
    if state.last_pattern == pattern, do: state.contact_repeat + 1, else: 1
  end

  defp contact_repeat(_state, _pattern, _position, _outcome), do: 0

  defp interact(false, @food, %{displaced?: false, coordination: coordination}, repeats, _hunger)
       when repeats >= 4 and coordination >= 0.30,
       do: {true, 0.0, :food_collected}

  defp interact(true, @home, %{displaced?: false, coordination: coordination}, repeats, hunger)
       when repeats >= 4 and coordination >= 0.30,
       do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}

  defp interact(carrying, _position, _outcome, _repeats, _hunger),
    do: {carrying, 0.0, :none}

  defp direction({x, _y}, {tx, _ty}) when x < tx, do: :east
  defp direction({x, _y}, {tx, _ty}) when x > tx, do: :west
  defp direction({_x, y}, {_tx, ty}) when y < ty, do: :south
  defp direction({_x, y}, {_tx, ty}) when y > ty, do: :north

  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(elem(@bounds, 1), y + 1)}
  defp move({x, y}, :east), do: {min(elem(@bounds, 0), x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}

  defp motor_cost(%{consequence: consequence})
       when consequence in [:displacement, :supported_displacement],
       do: 0.010

  defp motor_cost(%{consequence: :resisted_displacement}), do: 0.008
  defp motor_cost(_outcome), do: 0.004

  defp update_warmth(warmth, @home, _loss), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _position, loss), do: max(0.0, warmth - loss)

  defp returned_home?(records) do
    case Enum.find_index(records, &(&1.event == :food_collected)) do
      nil -> false
      index ->
        records
        |> Enum.drop(index + 1)
        |> Enum.any?(&(&1.position == @home and &1.carrying))
    end
  end

  defp summarize(rows) do
    rows
    |> Enum.group_by(& &1.condition)
    |> Map.new(fn {condition, selected} ->
      {condition,
       %{
         survived: Enum.count(selected, & &1.survived),
         survived_withdrawal: Enum.count(selected, & &1.survived_withdrawal),
         median_death_tick: median(Enum.map(selected, &(&1.death_tick * 1.0))),
         displaced: Enum.count(selected, & &1.displaced),
         first_displacement: positive_median(Enum.map(selected, &(&1.first_displacement * 1.0))),
         reached_food: Enum.count(selected, & &1.reached_food),
         collected: Enum.count(selected, & &1.collected),
         returned_home: Enum.count(selected, & &1.returned_home),
         consumed: Enum.count(selected, & &1.consumed),
         stable_patterns: mean(Enum.map(selected, &(&1.stable_patterns * 1.0))),
         displacement_rate: mean(Enum.map(selected, & &1.displacement_rate), 0.0),
         assistance_rate: mean(Enum.map(selected, & &1.assistance_rate), 0.0),
         contact_attempts: mean(Enum.map(selected, &(&1.contact_attempts * 1.0))),
         strongest_coordination: mean(Enum.map(selected, & &1.strongest_coordination), 0.0)
       }}
    end)
  end

  defp strongest_coordination(body) do
    case Body.strongest_patterns(body, 1) do
      [{_pattern, strength}] -> strength
      [] -> 0.0
    end
  end

  defp first_tick(records, predicate) do
    case Enum.find(records, predicate) do
      nil -> 0
      record -> record.tick
    end
  end

  defp fraction([], _predicate), do: 0.0
  defp fraction(records, predicate), do: Enum.count(records, predicate) / length(records)
  defp mean([], default \\ 0.0), do: default
  defp mean(values, _default), do: Enum.sum(values) / length(values)
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