defmodule Procession.Simulation.LearnerOwnedAssistanceExperiment do
  @moduledoc "Caregiver assistance teaches learner-owned home-foraging cycles."

  alias Procession.Simulation.DevelopmentalField

  @conditions [:provision_only, :abrupt_assistance, :staged_assistance]
  @actions [:manipulate, :wait, :north, :south, :east, :west]
  @home {0, 0}
  @field_opts [
    micro_nodes: 64,
    input_width: 3,
    consolidation_threshold: 4,
    coherence_threshold: 0.06,
    reuse_threshold: 0.50,
    edge_retention: 0.9995,
    activity_retention: 0.72,
    plasticity_fanout: 6,
    plasticity_budget: 0.08,
    minimum_compression_gain: 2.0
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 48)
    width = Keyword.get(opts, :stage_ticks, 40)
    withdrawal = Keyword.get(opts, :withdrawal_ticks, 120)
    seed = Keyword.get(opts, :seed, 1)
    total = width * 5 + withdrawal

    conditions =
      Map.new(@conditions, fn condition ->
        runs = Enum.map(1..population, &run_one(condition, width, total, seed, &1))
        {condition, summarize(runs, total)}
      end)

    %{
      population: population,
      stage_ticks: width,
      withdrawal_ticks: withdrawal,
      home: @home,
      conditions: conditions
    }
  end

  def report(result) do
    rows =
      Enum.map(@conditions, fn condition ->
        s = result.conditions[condition]

        "#{condition}: survived=#{s.survived}/#{result.population} " <>
          "completed_cycles=#{s.completed_cycles}/#{result.population} " <>
          "independent_cycles=#{s.independent_cycles}/#{result.population} " <>
          "food_reached=#{s.food_reached}/#{result.population} " <>
          "home_returns=#{s.home_returns}/#{result.population} " <>
          "intake=#{fmt(s.intake)} warmth=#{fmt(s.warmth)} " <>
          "ownership=#{fmt(s.ownership)} assistance=#{fmt(s.assistance)}"
      end)

    Enum.join(
      [
        "Learner-owned home foraging assistance",
        "population=#{result.population} stage_ticks=#{result.stage_ticks} " <>
          "withdrawal_ticks=#{result.withdrawal_ticks} home=#{inspect(result.home)}"
        | rows
      ],
      "\n"
    )
  end

  defp run_one(condition, width, total, seed, entity) do
    opts = Keyword.put(@field_opts, :encoding_salt, {:home_foraging, entity})

    initial = %{
      field: DevelopmentalField.new(opts),
      position: @home,
      vitality: 0.72,
      warmth: 1.0,
      carrying: false,
      alive?: true,
      tick: 0,
      records: [],
      memory: Map.new(@actions, &{&1, 0.0})
    }

    Enum.reduce_while(1..total, initial, fn tick, state ->
      stage = stage(tick, width)
      food = food_cell(stage)
      baseline_vitality = max(0.0, state.vitality - 0.010)
      warmth = update_warmth(state.warmth, state.position)
      hunger = 1.0 - baseline_vitality
      cold = 1.0 - warmth
      intended = choose(state, hunger, cold, tick, seed + entity * 137, opts)
      help = assist(condition, stage, intended, state, food, hunger, cold)
      action = help.action
      position = move(state.position, action)
      {carrying, intake, event} = interact(state.carrying, position, food, action, hunger)
      cost = action_cost(action, state.position, position, help.level)
      vitality = max(0.0, min(1.0, baseline_vitality - cost - cold * 0.006 + intake))
      memory = remember(state.memory, intended, action, event, intake, help.level)

      features = [
        {:development_stage, stage},
        {:body_channel, :hunger, bucket(hunger)},
        {:body_channel, :warmth, bucket(warmth)},
        {:body_channel, :cold_pressure, bucket(cold)},
        {:place_channel, position},
        {:home_relation, relation(position, @home)},
        {:food_relation, relation(position, food)},
        {:carrying_food, carrying},
        {:foraging_event, event},
        {:motor_intention, intended},
        {:caregiver_action, help.teacher},
        {:assistance_level, bucket(help.level)},
        {:learner_action_ownership, :very_high},
        {:motor_execution, action},
        {:self_intake_channel, intake > 0.0},
        {:change_channel, :vitality, trend(vitality - state.vitality)},
        {:change_channel, :warmth, trend(warmth - state.warmth)}
      ]

      field = DevelopmentalField.step(state.field, {:features, features}, opts)

      record = %{
        tick: tick,
        stage: stage,
        action: action,
        intended: intended,
        position: position,
        food: food,
        carrying: carrying,
        intake: intake,
        warmth: warmth,
        event: event,
        assistance: help.level,
        ownership: 1.0,
        teacher: help.teacher
      }

      next = %{
        state
        | field: field,
          position: position,
          vitality: vitality,
          warmth: warmth,
          carrying: carrying,
          alive?: vitality > 0.0 and warmth > 0.0,
          tick: tick,
          records: [record | state.records],
          memory: memory
      }

      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp choose(state, hunger, cold, tick, seed, opts) do
    @actions
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * 0.20
      pressure = max(hunger, cold) * 0.22
      wait_bias = if action == :wait, do: 0.18, else: 0.0
      learned = learned(state.field, action, opts) * 0.34
      memory = state.memory[action] * 0.55
      {action, exploration + pressure + wait_bias + learned + memory}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp assist(:provision_only, _stage, intended, _state, _food, _hunger, _cold),
    do: help(intended, :none, 0.0)

  defp assist(:abrupt_assistance, stage, _intended, state, food, hunger, cold)
       when stage != :withdrawal and (hunger > 0.34 or cold > 0.30) do
    target = guided_action(state, food)
    help(target, {:assist, target, :activate}, 1.0)
  end

  defp assist(:abrupt_assistance, _stage, intended, _state, _food, _hunger, _cold),
    do: help(intended, :none, 0.0)

  defp assist(:staged_assistance, stage, intended, state, food, hunger, cold)
       when stage != :withdrawal and (hunger > 0.30 or cold > 0.26) do
    target = guided_action(state, food)
    level = assistance_level(stage, intended == target)
    mode = if intended == target, do: :complete, else: :activate
    help(target, {:assist, target, mode}, level)
  end

  defp assist(:staged_assistance, _stage, intended, _state, _food, _hunger, _cold),
    do: help(intended, :none, 0.0)

  defp assistance_level(:full_guidance, _), do: 1.0
  defp assistance_level(:co_produced, true), do: 0.55
  defp assistance_level(:co_produced, false), do: 0.80
  defp assistance_level(:local_independent, true), do: 0.30
  defp assistance_level(:local_independent, false), do: 0.60
  defp assistance_level(:guided_approach, true), do: 0.20
  defp assistance_level(:guided_approach, false), do: 0.45
  defp assistance_level(:near_independent, true), do: 0.10
  defp assistance_level(:near_independent, false), do: 0.30

  defp guided_action(%{carrying: false, position: position}, food) when position == food,
    do: :manipulate

  defp guided_action(%{carrying: false, position: position}, food),
    do: direction(position, food)

  defp guided_action(%{carrying: true, position: @home}, _food), do: :manipulate

  defp guided_action(%{carrying: true, position: position}, _food),
    do: direction(position, @home)

  defp interact(false, position, position, :manipulate, _hunger),
    do: {true, 0.0, :food_collected}

  defp interact(true, @home, _food, :manipulate, hunger),
    do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}

  defp interact(carrying, _position, _food, _action, _hunger),
    do: {carrying, 0.0, :none}

  defp update_warmth(warmth, @home), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _position), do: max(0.0, warmth - 0.018)

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

  defp direction({x, _y}, {tx, _ty}) when x < tx, do: :east
  defp direction({x, _y}, {tx, _ty}) when x > tx, do: :west
  defp direction({_x, y}, {_tx, ty}) when y < ty, do: :south
  defp direction({_x, y}, {_tx, ty}) when y > ty, do: :north
  defp direction(position, position), do: :wait

  defp help(action, teacher, level), do: %{action: action, teacher: teacher, level: level}

  defp move(position, action) when action in [:manipulate, :wait], do: position
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}

  defp action_cost(:wait, _before, _after, level), do: 0.002 * effort(level)
  defp action_cost(:manipulate, _before, _after, level), do: 0.004 * effort(level)
  defp action_cost(_action, position, position, level), do: 0.008 * effort(level)
  defp action_cost(_action, _before, _after, level), do: 0.010 * effort(level)
  defp effort(level), do: max(0.25, 1.0 - level * 0.75)

  defp remember(memory, intended, action, event, intake, assistance) do
    decayed = Map.new(memory, fn {stored, value} -> {stored, value * 0.992} end)
    consequence = intake + if(event == :food_collected, do: 0.08, else: 0.0)
    gain = consequence * (0.45 + (1.0 - assistance) * 0.55)
    next = Map.update!(decayed, action, &min(1.0, &1 + gain))

    if intended == action,
      do: Map.update!(next, intended, &min(1.0, &1 + gain * 0.45)),
      else: next
  end

  defp learned(field, action, opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_execution, action}, opts)

    Enum.reduce(field.activity, 0.0, fn {source, activity}, total ->
      if activity >= 0.18 do
        total +
          Enum.reduce(targets, 0.0, fn target, acc ->
            acc + Map.get(field.edges, {source, target}, 0.0) * activity
          end)
      else
        total
      end
    end)
  end

  defp summarize(runs, total) do
    withdrawal = fn state -> Enum.filter(state.records, &(&1.stage == :withdrawal)) end

    %{
      survived: Enum.count(runs, &(&1.alive? and &1.tick == total)),
      completed_cycles:
        Enum.count(runs, &Enum.any?(&1.records, fn record -> record.event == :food_consumed_at_home end)),
      independent_cycles:
        Enum.count(runs, &Enum.any?(withdrawal.(&1), fn record -> record.event == :food_consumed_at_home end)),
      food_reached:
        Enum.count(runs, &Enum.any?(withdrawal.(&1), fn record -> record.position == record.food end)),
      home_returns:
        Enum.count(runs, &Enum.any?(withdrawal.(&1), fn record -> record.carrying and record.position == @home end)),
      intake: median(Enum.map(runs, &sum_stage(&1, :withdrawal, :intake))),
      warmth: median(Enum.map(runs, & &1.warmth)),
      ownership: median(Enum.map(runs, &mean(Enum.map(&1.records, fn record -> record.ownership end)))),
      assistance: median(Enum.map(runs, &mean(Enum.map(&1.records, fn record -> record.assistance end))))
    }
  end

  defp sum_stage(state, stage, key) do
    state.records
    |> Enum.filter(&(&1.stage == stage))
    |> Enum.reduce(0.0, &(Map.fetch!(&1, key) + &2))
  end

  defp relation(position, position), do: :contact

  defp relation({x, y}, {tx, ty}) when abs(x - tx) + abs(y - ty) == 1,
    do: :adjacent

  defp relation(_position, _target), do: :distant

  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_value), do: :very_high

  defp trend(delta) when delta > 0.01, do: :rising
  defp trend(delta) when delta < -0.01, do: :falling
  defp trend(_delta), do: :stable

  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp median([]), do: 0.0

  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)

    if rem(length(sorted), 2) == 1,
      do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
