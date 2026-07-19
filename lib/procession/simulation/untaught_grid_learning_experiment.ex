defmodule Procession.Simulation.UntaughtGridLearningExperiment do
  @moduledoc """
  Compares untaught, generally motivated, provisioned, and contingently taught
  learners inside the existing 4x4 embodied world while retaining the generic
  developmental field as the learner's mental substrate.

  Hunger never points directly to food. In motivated conditions it only raises
  broad non-rest action pressure. Resource identity is available only through
  stable local sensory signatures and the learner's own consequences.
  """

  alias Procession.Simulation.DevelopmentalField

  @conditions [:inert, :pressure_only, :provisioned, :contingent]
  @directions [:north, :south, :east, :west]
  @actions @directions ++ [:manipulate, :wait]
  @resources %{{0, 0} => :rough_cool, {3, 0} => :sweet_soft, {2, 3} => :sharp_dry}
  @distractors %{
    {1, 0} => :rough_cool,
    {0, 2} => :sweet_soft,
    {3, 2} => :sharp_dry,
    {1, 3} => :smooth_warm
  }

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
    population = Keyword.get(opts, :population, 32)
    ticks = Keyword.get(opts, :ticks, 240)
    training_ticks = Keyword.get(opts, :training_ticks, 160)
    seed = Keyword.get(opts, :seed, 1)

    conditions =
      Map.new(@conditions, fn condition ->
        runs = Enum.map(1..population, &run_entity(condition, ticks, training_ticks, seed, &1))
        {condition, summarize(runs, ticks, training_ticks)}
      end)

    %{population: population, ticks: ticks, training_ticks: training_ticks, conditions: conditions}
  end

  def report(result) do
    header = [
      "Untaught 4x4 developmental learner",
      "population=#{result.population} ticks=#{result.ticks} training_ticks=#{result.training_ticks} withdrawal_ticks=#{result.ticks - result.training_ticks}"
    ]

    lines =
      Enum.map(@conditions, fn condition ->
        s = Map.fetch!(result.conditions, condition)

        "#{condition}: survived=#{s.survived}/#{result.population} lifetime=#{fmt(s.median_lifetime)} " <>
          "intake=#{fmt(s.median_intake)} discoveries=#{fmt(s.median_discoveries)} " <>
          "motionless=#{fmt(s.median_motionless_fraction)} self_originated=#{fmt(s.median_self_originated_actions)} " <>
          "cells=#{fmt(s.median_cells_visited)} caregiver=#{fmt(s.median_caregiver_events)} " <>
          "withdrawal_survived=#{s.withdrawal_survived}/#{result.population} " <>
          "withdrawal_intake=#{fmt(s.median_withdrawal_intake)} withdrawal_actions=#{fmt(s.median_withdrawal_actions)} " <>
          "nodes=#{fmt(s.median_nodes)}"
      end)

    Enum.join(header ++ lines, "\n")
  end

  defp run_entity(condition, ticks, training_ticks, seed, entity) do
    field_opts = Keyword.put(@field_opts, :encoding_salt, {:untaught_grid_child, entity})

    initial = %{
      field: DevelopmentalField.new(field_opts),
      position: {1, 1},
      vitality: 0.62,
      fatigue: 0.0,
      resource_amounts: Map.new(Map.keys(@resources), &{&1, 0.75}),
      intake: 0.0,
      discoveries: 0,
      action_counts: Map.new(@actions, &{&1, 0}),
      visited: MapSet.new([{1, 1}]),
      caregiver_events: 0,
      ticks_without_intake: 0,
      alive?: true,
      tick: 0,
      records: []
    }

    Enum.reduce_while(1..ticks, initial, fn tick, state ->
      next = advance(state, condition, tick, training_ticks, seed + entity * 137, field_opts)
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp advance(state, condition, tick, training_ticks, seed, field_opts) do
    caregiver_active? = tick <= training_ticks
    amounts = regenerate(state.resource_amounts)
    depleted = max(0.0, state.vitality - 0.018)
    hunger = 1.0 - depleted
    signature = sensory_signature(state.position)

    {amounts, caregiver_action, cue} =
      caregiver(condition, caregiver_active?, state, amounts, hunger)

    action = choose_action(state, condition, hunger, signature, cue, tick, seed, field_opts)
    {position, fatigue} = move(state.position, action, state.fatigue)
    {amounts, intake, discovery?} = interact(amounts, position, action, hunger)
    vitality = min(1.0, depleted + intake)

    features = [
      {:body_channel, :vitality, bucket(vitality)},
      {:body_channel, :hunger, bucket(hunger)},
      {:body_channel, :fatigue, bucket(fatigue)},
      {:place_channel, position},
      {:sensory_channel, signature},
      {:motor_channel, action},
      {:change_channel, :vitality, trend(vitality - state.vitality)},
      {:intake_channel, intake > 0.0},
      {:caregiver_channel, caregiver_action}
    ]

    field = DevelopmentalField.step(state.field, {:features, features}, field_opts)
    record = %{tick: tick, action: action, intake: intake, caregiver: caregiver_action}

    %{
      state
      | field: field,
        position: position,
        vitality: vitality,
        fatigue: fatigue,
        resource_amounts: amounts,
        intake: state.intake + intake,
        discoveries: state.discoveries + bool_count(discovery?),
        action_counts: Map.update!(state.action_counts, action, &(&1 + 1)),
        visited: MapSet.put(state.visited, position),
        caregiver_events: state.caregiver_events + bool_count(caregiver_action != :none),
        ticks_without_intake: if(intake > 0.0, do: 0, else: state.ticks_without_intake + 1),
        alive?: vitality > 0.0,
        tick: tick,
        records: [record | state.records]
    }
  end

  defp caregiver(:provisioned, true, state, amounts, hunger) do
    if hunger > 0.62 and state.ticks_without_intake >= 6 do
      provisioned =
        Map.put(amounts, state.position, max(Map.get(amounts, state.position, 0.0), 0.28))

      {provisioned, :provision, :none}
    else
      {amounts, :none, :none}
    end
  end

  defp caregiver(:contingent, true, state, amounts, hunger) do
    if hunger > 0.58 and state.ticks_without_intake >= 4 do
      cue =
        if Map.get(amounts, state.position, 0.0) > 0.01 do
          :manipulate
        else
          direction_toward(state.position, nearest_resource(state.position, amounts))
        end

      {amounts, :cue, cue}
    else
      {amounts, :none, :none}
    end
  end

  defp caregiver(_condition, _active?, _state, amounts, _hunger),
    do: {amounts, :none, :none}

  defp choose_action(state, condition, hunger, signature, cue, tick, seed, field_opts) do
    @actions
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * 0.22
      rest = if action == :wait, do: 0.29 + state.fatigue * 0.30, else: 0.0
      pressure = general_pressure(condition, action, hunger, state.fatigue)
      object = if action == :manipulate and signature != :empty, do: 0.09, else: 0.0
      teaching = if action == cue, do: 0.34, else: 0.0
      learned = learned_motor_score(state.field, action, field_opts) * 0.42
      {action, exploration + rest + pressure + object + teaching + learned}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp general_pressure(:inert, _action, _hunger, _fatigue), do: 0.0
  defp general_pressure(_condition, :wait, _hunger, _fatigue), do: 0.0

  defp general_pressure(_condition, _action, hunger, fatigue),
    do: hunger * 0.30 * (1.0 - fatigue * 0.65)

  defp move(position, :wait, fatigue), do: {position, max(0.0, fatigue - 0.07)}
  defp move(position, :manipulate, fatigue), do: {position, max(0.0, fatigue - 0.02)}

  defp move(position, direction, fatigue) when direction in @directions,
    do: {step(position, direction), min(1.0, fatigue + 0.045)}

  defp interact(amounts, position, :manipulate, hunger) do
    available = Map.get(amounts, position, 0.0)

    if available > 0.0 do
      intake = min(available, min(0.22, hunger * 0.32))
      {Map.put(amounts, position, available - intake), intake, intake > 0.0}
    else
      {amounts, 0.0, false}
    end
  end

  defp interact(amounts, _position, _action, _hunger), do: {amounts, 0.0, false}

  defp sensory_signature(position),
    do: Map.get(@resources, position, Map.get(@distractors, position, :empty))

  defp regenerate(amounts) do
    Map.new(amounts, fn {position, amount} ->
      cap = if Map.has_key?(@resources, position), do: 0.75, else: 0.32
      regen = if Map.has_key?(@resources, position), do: 0.010, else: 0.0
      {position, min(cap, amount + regen)}
    end)
  end

  defp nearest_resource(position, amounts) do
    amounts
    |> Enum.filter(fn {_candidate, amount} -> amount > 0.02 end)
    |> Enum.min_by(fn {candidate, _amount} -> manhattan(position, candidate) end)
    |> elem(0)
  end

  defp direction_toward({x, _y}, {tx, _ty}) when x < tx, do: :east
  defp direction_toward({x, _y}, {tx, _ty}) when x > tx, do: :west
  defp direction_toward({_x, y}, {_tx, ty}) when y < ty, do: :south
  defp direction_toward({_x, y}, {_tx, ty}) when y > ty, do: :north
  defp direction_toward(_position, _target), do: :manipulate

  defp step({x, y}, :north), do: {x, max(0, y - 1)}
  defp step({x, y}, :south), do: {x, min(3, y + 1)}
  defp step({x, y}, :east), do: {min(3, x + 1), y}
  defp step({x, y}, :west), do: {max(0, x - 1), y}

  defp learned_motor_score(field, action, field_opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_channel, action}, field_opts)

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

  defp summarize(runs, ticks, training_ticks) do
    withdrawal = Enum.map(runs, &withdrawal_metrics(&1, training_ticks))

    %{
      survived: Enum.count(runs, & &1.alive?),
      median_lifetime: median(Enum.map(runs, & &1.tick)),
      median_intake: median(Enum.map(runs, & &1.intake)),
      median_discoveries: median(Enum.map(runs, &(&1.discoveries * 1.0))),
      median_motionless_fraction:
        median(Enum.map(runs, &(Map.fetch!(&1.action_counts, :wait) / max(1, &1.tick)))),
      median_self_originated_actions: median(Enum.map(runs, &(self_actions(&1) * 1.0))),
      median_cells_visited: median(Enum.map(runs, &(MapSet.size(&1.visited) * 1.0))),
      median_caregiver_events: median(Enum.map(runs, &(&1.caregiver_events * 1.0))),
      withdrawal_survived: Enum.count(runs, &(&1.alive? and &1.tick == ticks)),
      median_withdrawal_intake: median(Enum.map(withdrawal, & &1.intake)),
      median_withdrawal_actions: median(Enum.map(withdrawal, & &1.actions)),
      median_nodes: median(Enum.map(runs, &(MapSet.size(&1.field.generated) * 1.0)))
    }
  end

  defp withdrawal_metrics(state, training_ticks) do
    records = Enum.filter(state.records, &(&1.tick > training_ticks))

    %{
      intake: Enum.reduce(records, 0.0, &(&1.intake + &2)),
      actions: Enum.count(records, &(&1.action != :wait)) * 1.0
    }
  end

  defp self_actions(state) do
    Enum.reduce(state.action_counts, 0, fn
      {:wait, _count}, total -> total
      {_action, count}, total -> total + count
    end)
  end

  defp manhattan({x1, y1}, {x2, y2}), do: abs(x1 - x2) + abs(y1 - y2)
  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_value), do: :very_high
  defp trend(delta) when delta > 0.01, do: :rising
  defp trend(delta) when delta < -0.01, do: :falling
  defp trend(_delta), do: :stable
  defp bool_count(true), do: 1
  defp bool_count(false), do: 0
  defp median([]), do: 0.0

  defp median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)

    if rem(count, 2) == 1 do
      Enum.at(sorted, middle) * 1.0
    else
      (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
    end
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
