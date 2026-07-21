defmodule Procession.Simulation.HomeForagingChildScaleExperiment do
  @moduledoc "Paired emergent-motor comparison across a human-scale developmental timeline."

  alias Procession.Simulation.ChildDevelopmentSchedule, as: Schedule
  alias Procession.Simulation.DevelopmentalMotorBody, as: Body

  @home {0, 0}
  @food {3, 3}
  @bounds {3, 3}
  @physics %{vitality: 0.995, metabolic: 0.00035, warmth_loss: 0.0005,
    cold_cost: 0.00015, action_scale: 0.04}

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)
    scale = Keyword.get(opts, :phase_scale, 1.0)
    learning_scale = Keyword.get(opts, :motor_learning_scale, 0.01)
    phases = Schedule.phases(scale)
    total = Schedule.total_ticks(scale)
    teaching = Schedule.teaching_ticks(scale)
    care = Schedule.care_ticks(scale)

    rows = for condition <- [:no_teacher, :taught], entity <- 1..population do
      run_one(condition, entity, seed, phases, total, teaching, care, learning_scale)
    end

    %{population: population, phases: phases, total_ticks: total,
      teaching_ticks: teaching, care_ticks: care, rows: rows, summary: summarize(rows)}
  end

  def report(result) do
    phase_line = Enum.map_join(result.phases, ", ", fn phase ->
      "#{phase.name}=#{phase.ticks}h/motor#{phase.motor_support}/care#{phase.care}"
    end)

    lines = for condition <- [:no_teacher, :taught], summary = result.summary[condition] do
      "#{condition}: survived=#{summary.survived}/#{result.population} " <>
        "independent=#{summary.independent}/#{result.population} death=#{fmt(summary.death)} " <>
        "food=#{summary.food}/#{result.population} collected=#{summary.collected}/#{result.population} " <>
        "consumed=#{summary.consumed}/#{result.population} stable=#{fmt(summary.stable)} " <>
        "coordination=#{fmt(summary.coordination)} independent_moves=#{fmt(summary.independent_moves)} " <>
        "care_buffer=#{fmt(summary.provisioned)}"
    end

    Enum.join([
      "Human-scale emergent-motor comparison",
      "1 tick ~= 1 waking hour; birth-age 21 supported development plus age 21-25 independence",
      "motor learning scale=0.01; physical support fades early while reliable care fades through young adulthood",
      phase_line | lines
    ], "\n")
  end

  defp run_one(condition, entity, seed, phases, total, teaching, care_end, learning_scale) do
    physics = @physics
    initial = %{body: Body.new(), position: @home, vitality: physics.vitality, warmth: 1.0,
      carrying: false, alive?: true, tick: 0, last_pattern: nil, contact_repeat: 0,
      repertoire: %{}, provisioned: 0.0, records: []}

    final = Enum.reduce_while(1..total, initial, fn tick, state ->
      phase = phase_at(phases, tick)
      motor_support = if condition == :taught, do: phase.motor_support, else: 0.0
      care = if condition == :taught, do: phase.care, else: 0.0
      baseline = max(0.0, state.vitality - physics.metabolic)
      warmth_loss = physics.warmth_loss * (1.0 - care * 0.80)
      raw_warmth = update_warmth(state.warmth, state.position, warmth_loss)
      warmth = protect_warmth(raw_warmth, care)
      hunger = 1.0 - baseline
      cold = 1.0 - warmth
      goal = goal(state)
      {pattern, repertoire} = select_pattern(state, goal, tick, seed, entity, motor_support)

      {natural_body, natural} = Body.attempt(state.body, pattern, state.position, tick,
        seed: seed + entity * 1_003, bounds: @bounds)
      natural_body = scaled_body(state.body, natural_body, learning_scale)

      {body, outcome, position, assisted?} = support(state.body, natural_body, natural,
        state.position, pattern, goal, motor_support, seed, entity, tick, learning_scale)

      repeat = contact_repeat(state, pattern, position, outcome)
      {carrying, intake, event} = interact(state.carrying, position, outcome, repeat, hunger)
      effort = if assisted?, do: max(0.25, 1.0 - motor_support * 0.75), else: 1.0
      cost = motor_cost(outcome) * physics.action_scale * effort
      cold_cost = cold * physics.cold_cost * (1.0 - care * 0.85)
      raw_vitality = max(0.0, min(1.0, baseline - cost - cold_cost + intake))
      vitality = protect_vitality(raw_vitality, care)
      care_buffer = max(0.0, vitality - raw_vitality) + max(0.0, warmth - raw_warmth)

      record = %{tick: tick, displaced?: outcome.displaced?, position: position,
        event: event, assisted?: assisted?, provision: care_buffer}
      next = %{state | body: body, position: position, vitality: vitality, warmth: warmth,
        carrying: carrying, alive?: vitality > 0.0 and warmth > 0.0, tick: tick,
        last_pattern: pattern, contact_repeat: repeat, repertoire: repertoire,
        provisioned: state.provisioned + care_buffer, records: [record | state.records]}

      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)

    records = Enum.reverse(final.records)
    independent = Enum.filter(records, &(&1.tick > care_end))

    %{condition: condition, survived: final.alive? and final.tick == total,
      independent: final.tick > care_end, death: final.tick,
      food: Enum.any?(records, &(&1.position == @food)),
      collected: Enum.any?(records, &(&1.event == :food_collected)),
      consumed: Enum.any?(records, &(&1.event == :food_consumed_at_home)),
      stable: Body.stable_pattern_count(final.body), coordination: strongest(final.body),
      independent_moves: fraction(independent, & &1.displaced?),
      provisioned: final.provisioned,
      teaching_completed: final.tick > teaching}
  end

  defp protect_vitality(value, care) when care > 0.0,
    do: max(value, 0.20 + care * 0.65)
  defp protect_vitality(value, _care), do: value

  defp protect_warmth(value, care) when care > 0.0,
    do: max(value, 0.25 + care * 0.65)
  defp protect_warmth(value, _care), do: value

  defp phase_at(phases, tick) do
    phases |> Enum.reduce_while(0, fn phase, elapsed ->
      ending = elapsed + phase.ticks
      if tick <= ending, do: {:halt, phase}, else: {:cont, ending}
    end)
  end

  defp select_pattern(state, goal, tick, seed, entity, support) when support > 0.0 do
    case Map.fetch(state.repertoire, goal) do
      {:ok, pattern} -> {pattern, state.repertoire}
      :error ->
        pattern = Body.choose_pattern(state.body, tick, seed + entity * 149)
        {pattern, Map.put(state.repertoire, goal, pattern)}
    end
  end

  defp select_pattern(state, _goal, tick, seed, entity, _support),
    do: {Body.choose_pattern(state.body, tick, seed + entity * 149), state.repertoire}

  defp support(before, natural_body, natural, position, pattern, goal, amount,
         seed, entity, tick, learning_scale) do
    roll = :erlang.phash2({:child_support, seed, entity, tick}, 10_000) / 10_000

    if amount > 0.0 and roll < amount do
      supported = case goal do
        :contact -> Body.supported_stability(before, pattern, amount)
        direction -> Body.supported_attempt(before, pattern, direction, amount)
      end

      body = scaled_body(before, supported, learning_scale)
      coordination = Map.fetch!(body.coordination, pattern)

      if goal == :contact do
        outcome = %{natural | direction: :none, displaced?: false, blocked?: false,
          coordination: coordination, consequence: :supported_stability}
        {body, outcome, position, true}
      else
        outcome = %{natural | direction: goal, displaced?: true, blocked?: false,
          coordination: coordination, consequence: :supported_displacement}
        {body, outcome, move(position, goal), true}
      end
    else
      {natural_body, natural, Body.apply_displacement(position, natural), false}
    end
  end

  defp scaled_body(before, after_, scale) do
    coordination = Map.new(before.coordination, fn {pattern, old} ->
      {pattern, old + (Map.fetch!(after_.coordination, pattern) - old) * scale}
    end)

    stable = coordination
      |> Enum.filter(fn {_pattern, value} -> value >= 0.30 end)
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    %{after_ | coordination: coordination, stable_patterns: stable}
  end

  defp goal(%{carrying: false, position: @food}), do: :contact
  defp goal(%{carrying: false, position: position}), do: direction(position, @food)
  defp goal(%{carrying: true, position: @home}), do: :contact
  defp goal(%{carrying: true, position: position}), do: direction(position, @home)

  defp contact_repeat(state, pattern, position, %{displaced?: false}) when position in [@food, @home],
    do: if(state.last_pattern == pattern, do: state.contact_repeat + 1, else: 1)

  defp contact_repeat(_state, _pattern, _position, _outcome), do: 0

  defp interact(false, @food, %{displaced?: false, coordination: coordination}, repeats, _hunger)
       when repeats >= 4 and coordination >= 0.30,
       do: {true, 0.0, :food_collected}

  defp interact(true, @home, %{displaced?: false, coordination: coordination}, repeats, hunger)
       when repeats >= 4 and coordination >= 0.30,
       do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}

  defp interact(carrying, _position, _outcome, _repeats, _hunger),
    do: {carrying, 0.0, :none}

  defp direction({x, _y}, {target_x, _target_y}) when x < target_x, do: :east
  defp direction({x, _y}, {target_x, _target_y}) when x > target_x, do: :west
  defp direction({_x, y}, {_target_x, target_y}) when y < target_y, do: :south
  defp direction({_x, y}, {_target_x, target_y}) when y > target_y, do: :north
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}

  defp motor_cost(%{consequence: consequence})
       when consequence in [:displacement, :supported_displacement], do: 0.010
  defp motor_cost(%{consequence: :resisted_displacement}), do: 0.008
  defp motor_cost(_outcome), do: 0.004
  defp update_warmth(warmth, @home, _loss), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _position, loss), do: max(0.0, warmth - loss)

  defp strongest(body) do
    case Body.strongest_patterns(body, 1) do
      [{_pattern, value}] -> value
      [] -> 0.0
    end
  end

  defp summarize(rows) do
    rows
    |> Enum.group_by(& &1.condition)
    |> Map.new(fn {condition, selected} ->
      {condition, %{survived: Enum.count(selected, & &1.survived),
        independent: Enum.count(selected, & &1.independent),
        death: median(Enum.map(selected, &(&1.death * 1.0))),
        food: Enum.count(selected, & &1.food), collected: Enum.count(selected, & &1.collected),
        consumed: Enum.count(selected, & &1.consumed),
        stable: mean(Enum.map(selected, &(&1.stable * 1.0))),
        coordination: mean(Enum.map(selected, & &1.coordination), 0.0),
        independent_moves: mean(Enum.map(selected, & &1.independent_moves), 0.0),
        provisioned: mean(Enum.map(selected, & &1.provisioned), 0.0)}}
    end)
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

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end