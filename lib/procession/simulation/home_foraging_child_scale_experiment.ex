defmodule Procession.Simulation.HomeForagingChildScaleExperiment do
  @moduledoc "Paired emergent-motor comparison across a child-scale developmental timeline."

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

    rows = for condition <- [:no_teacher, :taught], entity <- 1..population do
      run_one(condition, entity, seed, phases, total, teaching, learning_scale)
    end

    %{population: population, phases: phases, total_ticks: total,
      teaching_ticks: teaching, rows: rows, summary: summarize(rows)}
  end

  def report(result) do
    phase_line = Enum.map_join(result.phases, ", ", fn p ->
      "#{p.name}=#{p.ticks}h/support#{p.support}"
    end)

    lines = for condition <- [:no_teacher, :taught], s = result.summary[condition] do
      "#{condition}: survived=#{s.survived}/#{result.population} " <>
        "transfer=#{s.transfer}/#{result.population} death=#{fmt(s.death)} " <>
        "food=#{s.food}/#{result.population} collected=#{s.collected}/#{result.population} " <>
        "consumed=#{s.consumed}/#{result.population} stable=#{fmt(s.stable)} " <>
        "coordination=#{fmt(s.coordination)} withdrawal_moves=#{fmt(s.withdrawal_moves)}"
    end

    Enum.join([
      "Child-scale emergent-motor comparison",
      "1 tick ~= 1 waking hour; birth-age 5 development plus age 5-7 unsupported transfer",
      "motor learning scale=0.01; paired seeds and initial bodies",
      phase_line | lines
    ], "\n")
  end

  defp run_one(condition, entity, seed, phases, total, teaching, learning_scale) do
    p = @physics
    initial = %{body: Body.new(), position: @home, vitality: p.vitality, warmth: 1.0,
      carrying: false, alive?: true, tick: 0, last_pattern: nil, contact_repeat: 0,
      repertoire: %{}, records: []}

    final = Enum.reduce_while(1..total, initial, fn tick, state ->
      phase = phase_at(phases, tick)
      support = if condition == :taught, do: phase.support, else: 0.0
      baseline = max(0.0, state.vitality - p.metabolic)
      warmth = update_warmth(state.warmth, state.position, p.warmth_loss)
      hunger = 1.0 - baseline
      cold = 1.0 - warmth
      goal = goal(state)
      {pattern, repertoire} = select_pattern(state, goal, tick, seed, entity, support)

      {natural_body, natural} = Body.attempt(state.body, pattern, state.position, tick,
        seed: seed + entity * 1_003, bounds: @bounds)
      natural_body = scaled_body(state.body, natural_body, learning_scale)

      {body, outcome, position, assisted?} = support(state.body, natural_body, natural,
        state.position, pattern, goal, support, seed, entity, tick, learning_scale)

      repeat = contact_repeat(state, pattern, position, outcome)
      {carrying, intake, event} = interact(state.carrying, position, outcome, repeat, hunger)
      effort = if assisted?, do: max(0.25, 1.0 - support * 0.75), else: 1.0
      cost = motor_cost(outcome) * p.action_scale * effort
      vitality = max(0.0, min(1.0, baseline - cost - cold * p.cold_cost + intake))

      record = %{tick: tick, displaced?: outcome.displaced?, position: position,
        event: event, assisted?: assisted?}
      next = %{state | body: body, position: position, vitality: vitality, warmth: warmth,
        carrying: carrying, alive?: vitality > 0.0 and warmth > 0.0, tick: tick,
        last_pattern: pattern, contact_repeat: repeat, repertoire: repertoire,
        records: [record | state.records]}

      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)

    records = Enum.reverse(final.records)
    withdrawal = Enum.filter(records, &(&1.tick > teaching))

    %{condition: condition, survived: final.alive? and final.tick == total,
      transfer: final.tick > teaching, death: final.tick,
      food: Enum.any?(records, &(&1.position == @food)),
      collected: Enum.any?(records, &(&1.event == :food_collected)),
      consumed: Enum.any?(records, &(&1.event == :food_consumed_at_home)),
      stable: Body.stable_pattern_count(final.body), coordination: strongest(final.body),
      withdrawal_moves: fraction(withdrawal, & &1.displaced?)}
  end

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
    stable = coordination |> Enum.filter(fn {_p, v} -> v >= 0.30 end)
      |> Enum.map(&elem(&1, 0)) |> MapSet.new()
    %{after_ | coordination: coordination, stable_patterns: stable}
  end

  defp goal(%{carrying: false, position: @food}), do: :contact
  defp goal(%{carrying: false, position: p}), do: direction(p, @food)
  defp goal(%{carrying: true, position: @home}), do: :contact
  defp goal(%{carrying: true, position: p}), do: direction(p, @home)

  defp contact_repeat(state, pattern, position, %{displaced?: false}) when position in [@food, @home],
    do: if(state.last_pattern == pattern, do: state.contact_repeat + 1, else: 1)
  defp contact_repeat(_state, _pattern, _position, _outcome), do: 0

  defp interact(false, @food, %{displaced?: false, coordination: c}, repeats, _)
       when repeats >= 4 and c >= 0.30, do: {true, 0.0, :food_collected}
  defp interact(true, @home, %{displaced?: false, coordination: c}, repeats, hunger)
       when repeats >= 4 and c >= 0.30,
       do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}
  defp interact(carrying, _, _, _, _), do: {carrying, 0.0, :none}

  defp direction({x, _}, {tx, _}) when x < tx, do: :east
  defp direction({x, _}, {tx, _}) when x > tx, do: :west
  defp direction({_, y}, {_, ty}) when y < ty, do: :south
  defp direction({_, y}, {_, ty}) when y > ty, do: :north
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}

  defp motor_cost(%{consequence: c}) when c in [:displacement, :supported_displacement], do: 0.010
  defp motor_cost(%{consequence: :resisted_displacement}), do: 0.008
  defp motor_cost(_), do: 0.004
  defp update_warmth(w, @home, _), do: min(1.0, w + 0.12)
  defp update_warmth(w, _, loss), do: max(0.0, w - loss)

  defp strongest(body) do
    case Body.strongest_patterns(body, 1) do
      [{_, value}] -> value
      [] -> 0.0
    end
  end

  defp summarize(rows) do
    rows |> Enum.group_by(& &1.condition) |> Map.new(fn {condition, selected} ->
      {condition, %{survived: Enum.count(selected, & &1.survived),
        transfer: Enum.count(selected, & &1.transfer), death: median(Enum.map(selected, &(&1.death * 1.0))),
        food: Enum.count(selected, & &1.food), collected: Enum.count(selected, & &1.collected),
        consumed: Enum.count(selected, & &1.consumed), stable: mean(Enum.map(selected, &(&1.stable * 1.0))),
        coordination: mean(Enum.map(selected, & &1.coordination)),
        withdrawal_moves: mean(Enum.map(selected, & &1.withdrawal_moves))}}
    end)
  end

  defp fraction([], _), do: 0.0
  defp fraction(records, predicate), do: Enum.count(records, predicate) / length(records)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp median([]), do: 0.0
  defp median(values) do
    s = Enum.sort(values); m = div(length(s), 2)
    if rem(length(s), 2) == 1, do: Enum.at(s, m), else: (Enum.at(s, m - 1) + Enum.at(s, m)) / 2
  end
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
