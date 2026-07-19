defmodule Procession.Simulation.FadingAssistanceExperiment do
  @moduledoc """
  Tests whether caregiver action guidance can fade through progressively larger
  learner-owned feeding sequences in the existing 4x4 world.
  """

  alias Procession.Simulation.DevelopmentalField

  @conditions [:provision_only, :abrupt_guidance, :staged_fading]
  @actions [:reach, :manipulate, :wait, :north, :south, :east, :west]
  @directions [:north, :south, :east, :west]
  @field_opts [micro_nodes: 64, input_width: 3, consolidation_threshold: 4,
    coherence_threshold: 0.06, reuse_threshold: 0.50, edge_retention: 0.9995,
    activity_retention: 0.72, plasticity_fanout: 6, plasticity_budget: 0.08,
    minimum_compression_gain: 2.0]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 48)
    stage_ticks = Keyword.get(opts, :stage_ticks, 40)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 100)
    seed = Keyword.get(opts, :seed, 1)
    assisted_ticks = stage_ticks * 5
    total = assisted_ticks + withdrawal_ticks

    conditions = Map.new(@conditions, fn condition ->
      runs = Enum.map(1..population, &run_entity(condition, stage_ticks, total, seed, &1))
      {condition, summarize(runs, assisted_ticks, total)}
    end)

    %{population: population, stage_ticks: stage_ticks,
      withdrawal_ticks: withdrawal_ticks, conditions: conditions}
  end

  def report(result) do
    lines = Enum.map(@conditions, fn condition ->
      s = Map.fetch!(result.conditions, condition)
      "#{condition}: survived=#{s.survived}/#{result.population} " <>
        "independent_self_feeders=#{s.independent_self_feeders}/#{result.population} " <>
        "transfer_reached=#{s.transfer_reached}/#{result.population} " <>
        "withdrawal_intake=#{fmt(s.median_withdrawal_intake)} " <>
        "learner_share=#{fmt(s.median_learner_share)} " <>
        "guided_actions=#{fmt(s.median_guided_actions)} " <>
        "cells=#{fmt(s.median_cells)} nodes=#{fmt(s.median_nodes)}"
    end)

    Enum.join(["Staged caregiver assistance fading in 4x4 world",
      "population=#{result.population} stage_ticks=#{result.stage_ticks} withdrawal_ticks=#{result.withdrawal_ticks}" | lines], "\n")
  end

  defp run_entity(condition, stage_ticks, total, seed, entity) do
    opts = Keyword.put(@field_opts, :encoding_salt, {:fading_assistance, entity})
    initial = %{field: DevelopmentalField.new(opts), position: {1, 1}, vitality: 0.68,
      alive?: true, tick: 0, records: [], visited: MapSet.new([{1, 1}]),
      motor_memory: Map.new(@actions, &{&1, 0.0})}

    Enum.reduce_while(1..total, initial, fn tick, state ->
      stage = stage(tick, stage_ticks)
      resource = resource(stage)
      depleted = max(0.0, state.vitality - 0.012)
      hunger = 1.0 - depleted
      intended = intended_action(state, hunger, tick, seed + entity * 137, opts)
      {executed, caregiver, learner_share} = execute(condition, stage, intended, state.position, resource, hunger)
      position = move(state.position, executed)
      intake = if position == resource and executed in [:reach, :manipulate], do: min(0.18, hunger * 0.30), else: 0.0
      vitality = min(1.0, depleted + intake)
      memory = update_memory(state.motor_memory, intended, executed, intake, learner_share)
      features = [{:development_stage, stage}, {:body_channel, :hunger, bucket(hunger)},
        {:place_channel, position}, {:resource_relation, relation(position, resource)},
        {:motor_intention, intended}, {:motor_execution, executed},
        {:caregiver_contact, caregiver}, {:learner_contribution, bucket(learner_share)},
        {:self_intake_channel, intake > 0.0}, {:change_channel, :vitality, trend(vitality - state.vitality)}]
      field = DevelopmentalField.step(state.field, {:features, features}, opts)
      record = %{tick: tick, stage: stage, intake: intake, position: position,
        resource: resource, caregiver: caregiver, learner_share: learner_share}
      next = %{state | field: field, position: position, vitality: vitality,
        alive?: vitality > 0.0, tick: tick, records: [record | state.records],
        visited: MapSet.put(state.visited, position), motor_memory: memory}
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp stage(tick, width) when tick <= width, do: :full_guidance
  defp stage(tick, width) when tick <= width * 2, do: :co_produced
  defp stage(tick, width) when tick <= width * 3, do: :local_independent
  defp stage(tick, width) when tick <= width * 4, do: :guided_approach
  defp stage(tick, width) when tick <= width * 5, do: :near_independent
  defp stage(_tick, _width), do: :withdrawal

  defp resource(stage) when stage in [:full_guidance, :co_produced, :local_independent], do: {1, 1}
  defp resource(stage) when stage in [:guided_approach, :near_independent], do: {2, 1}
  defp resource(:withdrawal), do: {2, 2}

  defp intended_action(state, hunger, tick, seed, opts) do
    @actions
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * 0.20
      baseline = if action == :wait, do: 0.25, else: hunger * 0.22
      learned = learned_score(state.field, action, opts) * 0.34
      memory = Map.fetch!(state.motor_memory, action) * 0.55
      {action, exploration + baseline + learned + memory}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp execute(:provision_only, _stage, intended, _position, _resource, _hunger),
    do: {intended, :position_resource, 1.0}

  defp execute(:abrupt_guidance, stage, intended, position, resource, hunger)
       when stage != :withdrawal and hunger > 0.42 do
    {guided_action(position, resource), :full_guidance, 0.0}
  end
  defp execute(:abrupt_guidance, _stage, intended, _position, _resource, _hunger),
    do: {intended, :none, 1.0}

  defp execute(:staged_fading, :full_guidance, _intended, position, resource, hunger)
       when hunger > 0.38,
       do: {guided_action(position, resource), :move_limb, 0.0}
  defp execute(:staged_fading, :co_produced, intended, position, resource, hunger)
       when hunger > 0.40 do
    target = guided_action(position, resource)
    if intended == target, do: {target, :complete_motion, 0.70}, else: {target, :redirect_motion, 0.35}
  end
  defp execute(:staged_fading, :local_independent, intended, position, resource, hunger)
       when hunger > 0.64 and position == resource and intended not in [:reach, :manipulate],
       do: {:manipulate, :rescue_completion, 0.55}
  defp execute(:staged_fading, :guided_approach, intended, position, resource, hunger)
       when hunger > 0.46 and position != resource do
    target = guided_action(position, resource)
    if intended == target, do: {target, :support_approach, 0.75}, else: {target, :redirect_approach, 0.45}
  end
  defp execute(:staged_fading, _stage, intended, _position, _resource, _hunger),
    do: {intended, :none, 1.0}

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

  defp update_memory(memory, intended, executed, intake, learner_share) do
    decayed = Map.new(memory, fn {action, value} -> {action, value * 0.992} end)
    gain = intake * (0.25 + learner_share * 0.75)
    decayed
    |> Map.update!(executed, &min(1.0, &1 + gain))
    |> then(fn next -> if intended == executed, do: Map.update!(next, intended, &min(1.0, &1 + gain * 0.45)), else: next end)
  end

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
    withdrawal = fn state -> Enum.filter(state.records, &(&1.stage == :withdrawal)) end
    %{survived: Enum.count(runs, &(&1.alive? and &1.tick == total)),
      independent_self_feeders: Enum.count(runs, fn state -> Enum.any?(withdrawal.(state), &(&1.intake > 0.0)) end),
      transfer_reached: Enum.count(runs, fn state -> Enum.any?(withdrawal.(state), &(&1.position == &1.resource)) end),
      median_withdrawal_intake: median(Enum.map(runs, fn state -> phase_intake(state, :withdrawal) end)),
      median_learner_share: median(Enum.map(runs, fn state -> mean(Enum.map(state.records, & &1.learner_share)) end)),
      median_guided_actions: median(Enum.map(runs, fn state -> Enum.count(state.records, &(&1.caregiver != :none)) * 1.0 end)),
      median_cells: median(Enum.map(runs, &(MapSet.size(&1.visited) * 1.0))),
      median_nodes: median(Enum.map(runs, &(MapSet.size(&1.field.generated) * 1.0))),
      assisted_ticks: assisted_ticks}
  end

  defp phase_intake(state, stage), do: state.records |> Enum.filter(&(&1.stage == stage)) |> Enum.reduce(0.0, &(&1.intake + &2))
  defp relation(position, position), do: :contact
  defp relation({x, y}, {tx, ty}) when abs(x - tx) + abs(y - ty) == 1, do: :adjacent
  defp relation(_position, _resource), do: :distant
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
    if rem(length(sorted), 2) == 1, do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
