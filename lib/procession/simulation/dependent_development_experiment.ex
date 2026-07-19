defmodule Procession.Simulation.DependentDevelopmentExperiment do
  @moduledoc """
  Exercises an explicit dependent baby phase, participatory transition, and
  caregiver withdrawal in the existing 4x4 embodied world with DevelopmentalField.
  """

  alias Procession.Simulation.DevelopmentalField

  @conditions [:orphan, :maintained_only, :participatory, :contingent]
  @directions [:north, :south, :east, :west]
  @actions [:signal, :orient, :reach, :manipulate, :wait] ++ @directions
  @resources %{{0, 0} => :rough_cool, {3, 0} => :sweet_soft, {2, 3} => :sharp_dry}
  @distractors %{{1, 0} => :rough_cool, {0, 2} => :sweet_soft, {3, 2} => :sharp_dry, {1, 3} => :smooth_warm}

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
    baby_ticks = Keyword.get(opts, :baby_ticks, 120)
    participation_ticks = Keyword.get(opts, :participation_ticks, 120)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 100)
    seed = Keyword.get(opts, :seed, 1)
    total = baby_ticks + participation_ticks + withdrawal_ticks

    conditions = Map.new(@conditions, fn condition ->
      runs = Enum.map(1..population, &run_entity(condition, total, baby_ticks, participation_ticks, seed, &1))
      {condition, summarize(runs, population, baby_ticks, participation_ticks, total)}
    end)

    %{population: population, baby_ticks: baby_ticks, participation_ticks: participation_ticks,
      withdrawal_ticks: withdrawal_ticks, total_ticks: total, conditions: conditions}
  end

  def report(result) do
    header = [
      "Dependent 4x4 developmental learner",
      "population=#{result.population} baby_ticks=#{result.baby_ticks} participation_ticks=#{result.participation_ticks} withdrawal_ticks=#{result.withdrawal_ticks}"
    ]

    lines = Enum.map(@conditions, fn condition ->
      s = Map.fetch!(result.conditions, condition)
      "#{condition}: baby_survived=#{s.baby_survived}/#{result.population} " <>
        "participation_survived=#{s.participation_survived}/#{result.population} " <>
        "withdrawal_survived=#{s.withdrawal_survived}/#{result.population} " <>
        "lifetime=#{fmt(s.median_lifetime)} intake=#{fmt(s.median_intake)} " <>
        "caregiver_intake=#{fmt(s.median_caregiver_intake)} self_intake=#{fmt(s.median_self_intake)} " <>
        "signals=#{fmt(s.median_signals)} participation=#{fmt(s.median_participation_actions)} " <>
        "withdrawal_intake=#{fmt(s.median_withdrawal_intake)} withdrawal_actions=#{fmt(s.median_withdrawal_actions)} " <>
        "cells=#{fmt(s.median_cells_visited)} nodes=#{fmt(s.median_nodes)}"
    end)

    Enum.join(header ++ lines, "\n")
  end

  defp run_entity(condition, total, baby_ticks, participation_ticks, seed, entity) do
    field_opts = Keyword.put(@field_opts, :encoding_salt, {:dependent_child, entity})
    initial = %{
      field: DevelopmentalField.new(field_opts), position: {1, 1}, vitality: 0.60,
      fatigue: 0.0, resource_amounts: Map.new(Map.keys(@resources), &{&1, 0.80}),
      intake: 0.0, caregiver_intake: 0.0, self_intake: 0.0,
      action_counts: Map.new(@actions, &{&1, 0}), visited: MapSet.new([{1, 1}]),
      alive?: true, tick: 0, records: []
    }

    Enum.reduce_while(1..total, initial, fn tick, state ->
      next = advance(state, condition, tick, baby_ticks, participation_ticks, seed + entity * 137, field_opts)
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp advance(state, condition, tick, baby_ticks, participation_ticks, seed, field_opts) do
    phase = phase(tick, baby_ticks, participation_ticks)
    amounts = regenerate(state.resource_amounts)
    depleted = max(0.0, state.vitality - 0.014)
    hunger = 1.0 - depleted
    signature = sensory_signature(state.position)
    action = choose_action(state, condition, phase, hunger, signature, tick, seed, field_opts)
    {position, fatigue} = move(state.position, action, state.fatigue, phase)
    {amounts, self_intake} = interact(amounts, position, action, hunger, phase)
    {amounts, caregiver_intake, caregiver_action} = caregiver(condition, phase, position, amounts, hunger, self_intake)
    vitality = min(1.0, depleted + self_intake + caregiver_intake)

    features = [
      {:development_phase, phase}, {:body_channel, :vitality, bucket(vitality)},
      {:body_channel, :hunger, bucket(hunger)}, {:body_channel, :fatigue, bucket(fatigue)},
      {:place_channel, position}, {:sensory_channel, signature}, {:motor_channel, action},
      {:caregiver_channel, caregiver_action}, {:self_intake_channel, self_intake > 0.0},
      {:caregiver_intake_channel, caregiver_intake > 0.0},
      {:change_channel, :vitality, trend(vitality - state.vitality)}
    ]

    field = DevelopmentalField.step(state.field, {:features, features}, field_opts)
    record = %{tick: tick, phase: phase, action: action, self_intake: self_intake,
      caregiver_intake: caregiver_intake, caregiver: caregiver_action}

    %{state | field: field, position: position, vitality: vitality, fatigue: fatigue,
      resource_amounts: amounts, intake: state.intake + self_intake + caregiver_intake,
      caregiver_intake: state.caregiver_intake + caregiver_intake,
      self_intake: state.self_intake + self_intake,
      action_counts: Map.update!(state.action_counts, action, &(&1 + 1)),
      visited: MapSet.put(state.visited, position), alive?: vitality > 0.0,
      tick: tick, records: [record | state.records]}
  end

  defp phase(tick, baby_ticks, _participation_ticks) when tick <= baby_ticks, do: :baby
  defp phase(tick, baby_ticks, participation_ticks) when tick <= baby_ticks + participation_ticks, do: :participation
  defp phase(_tick, _baby_ticks, _participation_ticks), do: :withdrawal

  defp caregiver(:orphan, _phase, _position, amounts, _hunger, _self_intake), do: {amounts, 0.0, :none}
  defp caregiver(_condition, :withdrawal, _position, amounts, _hunger, _self_intake), do: {amounts, 0.0, :none}
  defp caregiver(_condition, _phase, _position, amounts, _hunger, self_intake) when self_intake > 0.0,
    do: {amounts, 0.0, :observe_success}

  defp caregiver(:maintained_only, _phase, _position, amounts, hunger, _self_intake),
    do: direct_feed(amounts, hunger, :maintain)
  defp caregiver(:participatory, :baby, _position, amounts, hunger, _self_intake),
    do: direct_feed(amounts, hunger, :feed_and_expose)
  defp caregiver(:contingent, :baby, _position, amounts, hunger, _self_intake),
    do: direct_feed(amounts, hunger, :feed_and_expose)

  defp caregiver(:participatory, :participation, position, amounts, hunger, _self_intake) do
    if hunger > 0.58 do
      placed = Map.put(amounts, position, max(Map.get(amounts, position, 0.0), 0.20))
      {placed, 0.0, :provision_for_participation}
    else
      {amounts, 0.0, :none}
    end
  end

  defp caregiver(:contingent, :participation, position, amounts, hunger, _self_intake) do
    cond do
      hunger <= 0.52 -> {amounts, 0.0, :none}
      Map.get(amounts, position, 0.0) > 0.01 -> {amounts, 0.0, :cue_manipulate}
      true -> {amounts, 0.0, {:cue_direction, direction_toward(position, nearest_resource(position, amounts))}}
    end
  end

  defp direct_feed(amounts, hunger, action) do
    intake = if hunger > 0.38, do: min(0.20, hunger * 0.30), else: 0.0
    {amounts, intake, if(intake > 0.0, do: action, else: :none)}
  end

  defp choose_action(state, condition, phase, hunger, signature, tick, seed, field_opts) do
    cue = caregiver_cue(condition, phase, state.position, state.resource_amounts, hunger)

    allowed_actions(phase)
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * exploration_gain(phase)
      baseline = baseline(action, phase, state.fatigue)
      pressure = if action == :wait, do: 0.0, else: hunger * pressure_gain(phase)
      object = if action in [:reach, :manipulate] and signature != :empty, do: 0.08, else: 0.0
      teaching = if action_matches_cue?(action, cue), do: 0.34, else: 0.0
      learned = learned_motor_score(state.field, action, field_opts) * 0.40
      {action, exploration + baseline + pressure + object + teaching + learned}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp caregiver_cue(:contingent, :participation, position, amounts, hunger) when hunger > 0.52 do
    if Map.get(amounts, position, 0.0) > 0.01,
      do: :manipulate,
      else: direction_toward(position, nearest_resource(position, amounts))
  end
  defp caregiver_cue(_condition, _phase, _position, _amounts, _hunger), do: :none
  defp action_matches_cue?(_action, :none), do: false
  defp action_matches_cue?(action, cue), do: action == cue

  defp allowed_actions(:baby), do: [:signal, :orient, :reach, :wait]
  defp allowed_actions(_phase), do: @actions
  defp exploration_gain(:baby), do: 0.12
  defp exploration_gain(_phase), do: 0.22
  defp pressure_gain(:baby), do: 0.12
  defp pressure_gain(:participation), do: 0.26
  defp pressure_gain(:withdrawal), do: 0.30
  defp baseline(:wait, :baby, fatigue), do: 0.36 + fatigue * 0.25
  defp baseline(:wait, _phase, fatigue), do: 0.27 + fatigue * 0.28
  defp baseline(:signal, :baby, _fatigue), do: 0.12
  defp baseline(_action, _phase, _fatigue), do: 0.0

  defp move(position, action, fatigue, :baby) when action in @directions, do: {position, fatigue}
  defp move(position, :wait, fatigue, _phase), do: {position, max(0.0, fatigue - 0.07)}
  defp move(position, action, fatigue, _phase) when action in [:signal, :orient, :reach, :manipulate],
    do: {position, max(0.0, fatigue - 0.02)}
  defp move(position, direction, fatigue, _phase) when direction in @directions,
    do: {step(position, direction), min(1.0, fatigue + 0.045)}

  defp interact(amounts, position, action, hunger, phase)
       when action in [:reach, :manipulate] and phase != :baby do
    available = Map.get(amounts, position, 0.0)
    if available > 0.0 do
      intake = min(available, min(0.20, hunger * 0.30))
      {Map.put(amounts, position, available - intake), intake}
    else
      {amounts, 0.0}
    end
  end
  defp interact(amounts, _position, _action, _hunger, _phase), do: {amounts, 0.0}

  defp sensory_signature(position), do: Map.get(@resources, position, Map.get(@distractors, position, :empty))
  defp regenerate(amounts), do: Map.new(amounts, fn {position, amount} ->
    {position, min(0.80, amount + 0.010)}
  end)

  defp nearest_resource(position, amounts) do
    amounts |> Enum.filter(fn {_p, amount} -> amount > 0.02 end)
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
        total + Enum.reduce(targets, 0.0, fn target, acc ->
          acc + Map.get(field.edges, {source, target}, 0.0) * activity
        end)
      else
        total
      end
    end)
  end

  defp summarize(runs, population, baby_ticks, participation_ticks, total) do
    baby_end = baby_ticks
    participation_end = baby_ticks + participation_ticks
    %{
      baby_survived: Enum.count(runs, &(&1.tick >= baby_end)),
      participation_survived: Enum.count(runs, &(&1.tick >= participation_end)),
      withdrawal_survived: Enum.count(runs, &(&1.alive? and &1.tick == total)),
      median_lifetime: median(Enum.map(runs, &(&1.tick * 1.0))),
      median_intake: median(Enum.map(runs, & &1.intake)),
      median_caregiver_intake: median(Enum.map(runs, & &1.caregiver_intake)),
      median_self_intake: median(Enum.map(runs, & &1.self_intake)),
      median_signals: median(Enum.map(runs, &(Map.get(&1.action_counts, :signal, 0) * 1.0))),
      median_participation_actions: median(Enum.map(runs, &phase_actions(&1, :participation))),
      median_withdrawal_intake: median(Enum.map(runs, &phase_intake(&1, :withdrawal))),
      median_withdrawal_actions: median(Enum.map(runs, &phase_actions(&1, :withdrawal))),
      median_cells_visited: median(Enum.map(runs, &(MapSet.size(&1.visited) * 1.0))),
      median_nodes: median(Enum.map(runs, &(MapSet.size(&1.field.generated) * 1.0))),
      population: population
    }
  end

  defp phase_actions(state, phase), do: state.records |> Enum.count(&(&1.phase == phase and &1.action != :wait)) |> Kernel.*(1.0)
  defp phase_intake(state, phase), do: state.records |> Enum.filter(&(&1.phase == phase))
    |> Enum.reduce(0.0, &(&1.self_intake + &2))
  defp manhattan({x1, y1}, {x2, y2}), do: abs(x1 - x2) + abs(y1 - y2)
  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_value), do: :very_high
  defp trend(delta) when delta > 0.01, do: :rising
  defp trend(delta) when delta < -0.01, do: :falling
  defp trend(_delta), do: :stable
  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    count = length(sorted)
    middle = div(count, 2)
    if rem(count, 2) == 1, do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
