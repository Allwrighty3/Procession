defmodule Procession.Simulation.PhysicalGuidanceExperiment do
  @moduledoc """
  Compares caregiver influence over learner action in the existing 4x4 embodied world.
  Assistance is withdrawn and the usable resource is moved to test transfer.
  """

  alias Procession.Simulation.DevelopmentalField

  @conditions [:provision_only, :passive_guidance, :co_produced, :positioning_only]
  @actions [:reach, :manipulate, :wait, :north, :south, :east, :west]
  @field_opts [micro_nodes: 64, input_width: 3, consolidation_threshold: 4,
    coherence_threshold: 0.06, reuse_threshold: 0.50, edge_retention: 0.9995,
    activity_retention: 0.72, plasticity_fanout: 6, plasticity_budget: 0.08,
    minimum_compression_gain: 2.0]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 48)
    assisted_ticks = Keyword.get(opts, :assisted_ticks, 160)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 100)
    seed = Keyword.get(opts, :seed, 1)
    total = assisted_ticks + withdrawal_ticks

    conditions = Map.new(@conditions, fn condition ->
      runs = Enum.map(1..population, &run_entity(condition, assisted_ticks, total, seed, &1))
      {condition, summarize(runs, assisted_ticks, total)}
    end)

    %{population: population, assisted_ticks: assisted_ticks,
      withdrawal_ticks: withdrawal_ticks, conditions: conditions}
  end

  def report(result) do
    lines = Enum.map(@conditions, fn condition ->
      s = Map.fetch!(result.conditions, condition)
      "#{condition}: survived=#{s.survived}/#{result.population} " <>
        "independent_self_feeders=#{s.independent_self_feeders}/#{result.population} " <>
        "median_first_independent=#{fmt(s.median_first_independent)} " <>
        "assisted_intake=#{fmt(s.median_assisted_intake)} " <>
        "withdrawal_intake=#{fmt(s.median_withdrawal_intake)} " <>
        "learner_contribution=#{fmt(s.median_learner_contribution)} " <>
        "guided_actions=#{fmt(s.median_guided_actions)} " <>
        "moved_resource_reached=#{s.moved_resource_reached}/#{result.population} " <>
        "cells=#{fmt(s.median_cells)} nodes=#{fmt(s.median_nodes)}"
    end)

    Enum.join(["Physical caregiver guidance in 4x4 world",
      "population=#{result.population} assisted_ticks=#{result.assisted_ticks} withdrawal_ticks=#{result.withdrawal_ticks}" | lines], "\n")
  end

  defp run_entity(condition, assisted_ticks, total, seed, entity) do
    opts = Keyword.put(@field_opts, :encoding_salt, {:physical_guidance, entity})
    initial = %{field: DevelopmentalField.new(opts), position: {1, 1}, vitality: 0.62,
      alive?: true, tick: 0, intake: 0.0, records: [], visited: MapSet.new([{1, 1}])}

    Enum.reduce_while(1..total, initial, fn tick, state ->
      phase = if tick <= assisted_ticks, do: :assisted, else: :withdrawal
      resource = if phase == :assisted, do: {1, 1}, else: {2, 1}
      depleted = max(0.0, state.vitality - 0.014)
      hunger = 1.0 - depleted
      intended = intended_action(state, hunger, tick, seed + entity * 137, opts)
      {executed, caregiver, learner_share} = execute(condition, phase, intended, state.position, resource, hunger)
      position = move(state.position, executed)
      intake = if position == resource and executed in [:reach, :manipulate], do: min(0.20, hunger * 0.30), else: 0.0
      vitality = min(1.0, depleted + intake)
      features = [{:body_channel, :hunger, bucket(hunger)}, {:place_channel, position},
        {:motor_intention, intended}, {:motor_execution, executed}, {:caregiver_contact, caregiver},
        {:learner_contribution, bucket(learner_share)}, {:self_intake_channel, intake > 0.0},
        {:change_channel, :vitality, trend(vitality - state.vitality)}]
      field = DevelopmentalField.step(state.field, {:features, features}, opts)
      record = %{tick: tick, phase: phase, intended: intended, executed: executed,
        caregiver: caregiver, learner_share: learner_share, intake: intake, position: position,
        resource: resource}
      next = %{state | field: field, position: position, vitality: vitality,
        alive?: vitality > 0.0, tick: tick, intake: state.intake + intake,
        records: [record | state.records], visited: MapSet.put(state.visited, position)}
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp intended_action(state, hunger, tick, seed, opts) do
    @actions
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * 0.22
      baseline = if action == :wait, do: 0.28, else: hunger * 0.24
      learned = learned_score(state.field, action, opts) * 0.42
      {action, exploration + baseline + learned}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp execute(_condition, :withdrawal, intended, _position, _resource, _hunger), do: {intended, :none, 1.0}
  defp execute(:provision_only, :assisted, intended, _position, _resource, _hunger), do: {intended, :position_resource, 1.0}
  defp execute(:positioning_only, :assisted, intended, _position, _resource, _hunger), do: {intended, :stabilize, 1.0}
  defp execute(:passive_guidance, :assisted, _intended, position, resource, hunger) when hunger > 0.45 do
    {guided_action(position, resource), :move_limb, 0.0}
  end
  defp execute(:co_produced, :assisted, intended, position, resource, hunger) when hunger > 0.45 do
    target = guided_action(position, resource)
    if intended == target, do: {target, :complete_motion, 0.55}, else: {target, :redirect_and_complete, 0.25}
  end
  defp execute(_condition, :assisted, intended, _position, _resource, _hunger), do: {intended, :none, 1.0}

  defp guided_action(position, position), do: :manipulate
  defp guided_action({x, _y}, {tx, _ty}) when x < tx, do: :east
  defp guided_action({x, _y}, {tx, _ty}) when x > tx, do: :west
  defp guided_action({_x, y}, {_tx, ty}) when y < ty, do: :south
  defp guided_action({_x, y}, {_tx, ty}) when y > ty, do: :north

  defp move(position, action) when action in [:reach, :manipulate, :wait], do: position
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}

  defp learned_score(field, action, opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_execution, action}, opts)
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

  defp summarize(runs, assisted_ticks, total) do
    withdrawal = fn state -> Enum.filter(state.records, &(&1.phase == :withdrawal)) end
    first_independent = fn state ->
      state.records |> Enum.filter(&(&1.phase == :withdrawal and &1.intake > 0.0))
      |> Enum.map(& &1.tick) |> Enum.min(fn -> 0 end) |> Kernel.*(1.0)
    end
    %{survived: Enum.count(runs, &(&1.alive? and &1.tick == total)),
      independent_self_feeders: Enum.count(runs, fn state -> Enum.any?(withdrawal.(state), &(&1.intake > 0.0)) end),
      median_first_independent: median(Enum.map(runs, first_independent)),
      median_assisted_intake: median(Enum.map(runs, fn s -> phase_intake(s, :assisted) end)),
      median_withdrawal_intake: median(Enum.map(runs, fn s -> phase_intake(s, :withdrawal) end)),
      median_learner_contribution: median(Enum.map(runs, fn s -> mean(Enum.map(s.records, & &1.learner_share)) end)),
      median_guided_actions: median(Enum.map(runs, fn s -> Enum.count(s.records, &(&1.caregiver != :none)) * 1.0 end)),
      moved_resource_reached: Enum.count(runs, fn s -> Enum.any?(withdrawal.(s), &(&1.position == &1.resource)) end),
      median_cells: median(Enum.map(runs, &(MapSet.size(&1.visited) * 1.0))),
      median_nodes: median(Enum.map(runs, &(MapSet.size(&1.field.generated) * 1.0))),
      assisted_ticks: assisted_ticks}
  end

  defp phase_intake(state, phase), do: state.records |> Enum.filter(&(&1.phase == phase)) |> Enum.reduce(0.0, &(&1.intake + &2))
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
    sorted = Enum.sort(values); middle = div(length(sorted), 2)
    if rem(length(sorted), 2) == 1, do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
