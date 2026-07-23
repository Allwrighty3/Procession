defmodule Procession.Simulation.FadingAssistanceSurvivorTrace do
  @moduledoc false

  alias Procession.Simulation.DevelopmentalField

  @actions [:reach, :manipulate, :wait, :north, :south, :east, :west]
  @field_opts [micro_nodes: 64, input_width: 3, consolidation_threshold: 4,
    coherence_threshold: 0.06, reuse_threshold: 0.50, edge_retention: 0.9995,
    activity_retention: 0.72, plasticity_fanout: 6, plasticity_budget: 0.08,
    minimum_compression_gain: 2.0]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 48)
    stage_ticks = Keyword.get(opts, :stage_ticks, 40)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 100)
    seed = Keyword.get(opts, :seed, 1)
    total = stage_ticks * 5 + withdrawal_ticks

    1..population
    |> Enum.map(&run_entity(&1, stage_ticks, total, seed))
    |> Enum.filter(&(&1.alive? and &1.tick == total))
    |> Enum.map(&summarize_survivor/1)
  end

  def report([]), do: "No survivors"
  def report(survivors), do: Enum.map_join(survivors, "\n\n", &survivor_report/1)

  defp run_entity(entity, stage_ticks, total, seed) do
    opts = Keyword.put(@field_opts, :encoding_salt, {:fading_assistance, entity})
    initial = %{entity: entity, field: DevelopmentalField.new(opts), position: {1, 1},
      vitality: 0.68, alive?: true, tick: 0, records: [],
      motor_memory: Map.new(@actions, &{&1, 0.0})}

    Enum.reduce_while(1..total, initial, fn tick, state ->
      stage = stage(tick, stage_ticks)
      resource = resource(stage)
      baseline_depleted = max(0.0, state.vitality - 0.012)
      hunger = 1.0 - baseline_depleted
      intended = intended_action(state, hunger, tick, seed + entity * 137, opts)
      {executed, caregiver, learner_share} = execute(stage, intended, state.position, resource, hunger)
      position = move(state.position, executed)
      cost = action_cost(executed, state.position, position, learner_share)
      depleted = max(0.0, baseline_depleted - cost)
      intake = if position == resource and executed in [:reach, :manipulate],
        do: min(0.18, hunger * 0.30), else: 0.0
      vitality = min(1.0, depleted + intake)
      memory = update_memory(state.motor_memory, intended, executed, intake, learner_share)
      features = [{:development_stage, stage}, {:body_channel, :hunger, bucket(hunger)},
        {:place_channel, position}, {:resource_relation, relation(position, resource)},
        {:motor_intention, intended}, {:motor_execution, executed},
        {:action_outcome, action_outcome(executed, state.position, position)},
        {:action_cost_channel, bucket_cost(cost)}, {:caregiver_contact, caregiver},
        {:learner_contribution, bucket(learner_share)}, {:self_intake_channel, intake > 0.0},
        {:change_channel, :vitality, trend(vitality - state.vitality)}]
      field = DevelopmentalField.step(state.field, {:features, features}, opts)
      record = %{tick: tick, stage: stage, before: state.position, position: position,
        resource: resource, hunger: hunger, vitality: vitality, intended: intended,
        executed: executed, caregiver: caregiver, learner_share: learner_share,
        cost: cost, intake: intake}
      next = %{state | field: field, position: position, vitality: vitality,
        alive?: vitality > 0.0, tick: tick, records: [record | state.records],
        motor_memory: memory}
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp summarize_survivor(state) do
    records = Enum.reverse(state.records)
    withdrawal = Enum.filter(records, &(&1.stage == :withdrawal))
    feed_ticks = Enum.filter(withdrawal, &(&1.intake > 0.0))
    first_feed = List.first(feed_ticks)
    window = if first_feed,
      do: Enum.filter(withdrawal, &(&1.tick >= first_feed.tick - 8 and &1.tick <= first_feed.tick + 4)),
      else: withdrawal
    %{entity: state.entity, final_vitality: state.vitality, final_memory: state.motor_memory,
      feeding_ticks: Enum.map(feed_ticks, & &1.tick), feeding_window: window,
      compressed_sequence: compress(Enum.map(withdrawal, & &1.executed))}
  end

  defp survivor_report(s) do
    memory = s.final_memory |> Enum.sort_by(fn {_k, v} -> -v end)
      |> Enum.map_join(", ", fn {k, v} -> "#{k}=#{fmt(v)}" end)
    window = Enum.map_join(s.feeding_window, "\n", fn r ->
      "t=#{r.tick} pos=#{inspect(r.before)}->#{inspect(r.position)} resource=#{inspect(r.resource)} " <>
      "intend=#{r.intended} execute=#{r.executed} intake=#{fmt(r.intake)} " <>
      "cost=#{fmt(r.cost)} vitality=#{fmt(r.vitality)}"
    end)
    "entity=#{s.entity} final_vitality=#{fmt(s.final_vitality)} feeding_ticks=#{inspect(s.feeding_ticks)}\n" <>
      "learned_sequence=#{inspect(s.compressed_sequence)}\nfinal_memory=#{memory}\nfeeding_window:\n#{window}"
  end

  defp compress([]), do: []
  defp compress([head | tail]) do
    {groups, action, count} = Enum.reduce(tail, {[], head, 1}, fn next, {acc, current, n} ->
      if next == current, do: {acc, current, n + 1}, else: {[{current, n} | acc], next, 1}
    end)
    Enum.reverse([{action, count} | groups])
  end

  defp stage(tick, width) when tick <= width, do: :full_guidance
  defp stage(tick, width) when tick <= width * 2, do: :co_produced
  defp stage(tick, width) when tick <= width * 3, do: :local_independent
  defp stage(tick, width) when tick <= width * 4, do: :guided_approach
  defp stage(tick, width) when tick <= width * 5, do: :near_independent
  defp stage(_, _), do: :withdrawal

  defp resource(stage) when stage in [:full_guidance, :co_produced, :local_independent], do: {1, 1}
  defp resource(stage) when stage in [:guided_approach, :near_independent], do: {2, 1}
  defp resource(:withdrawal), do: {2, 2}

  defp intended_action(state, hunger, tick, seed, opts) do
    @actions |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * 0.20
      baseline = if action == :wait, do: 0.25, else: hunger * 0.22
      learned = learned_score(state.field, action, opts) * 0.34
      memory = Map.fetch!(state.motor_memory, action) * 0.55
      {action, exploration + baseline + learned + memory}
    end) |> Enum.max_by(fn {action, score} -> {score, action} end) |> elem(0)
  end

  defp execute(stage, _intended, position, resource, hunger)
       when stage != :withdrawal and hunger > 0.42,
       do: {guided_action(position, resource), :full_guidance, 0.0}
  defp execute(_, intended, _, _, _), do: {intended, :none, 1.0}

  defp guided_action(position, position), do: :manipulate
  defp guided_action({x, _}, {tx, _}) when x < tx, do: :east
  defp guided_action({x, _}, {tx, _}) when x > tx, do: :west
  defp guided_action({_, y}, {_, ty}) when y < ty, do: :south
  defp guided_action({_, y}, {_, ty}) when y > ty, do: :north

  defp move(position, action) when action in [:reach, :manipulate, :wait], do: position
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}

  defp action_cost(:wait, _, _, share), do: 0.002 * share
  defp action_cost(action, _, _, share) when action in [:reach, :manipulate], do: 0.004 * share
  defp action_cost(_, position, position, share), do: 0.008 * share
  defp action_cost(_, _, _, share), do: 0.010 * share

  defp update_memory(memory, intended, executed, intake, learner_share) do
    gain = intake * (0.25 + learner_share * 0.75)
    memory |> Map.new(fn {a, v} -> {a, v * 0.992} end)
    |> Map.update!(executed, &min(1.0, &1 + gain))
    |> then(fn next -> if intended == executed,
      do: Map.update!(next, intended, &min(1.0, &1 + gain * 0.45)), else: next end)
  end

  defp learned_score(field, action, opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_execution, action}, opts)
    Enum.reduce(field.activity, 0.0, fn {source, activity}, total ->
      if activity >= 0.18 do
        total + Enum.reduce(targets, 0.0, fn target, acc ->
          acc + Map.get(field.edges, {source, target}, 0.0) * activity
        end)
      else total end
    end)
  end

  defp relation(position, position), do: :contact
  defp relation({x, y}, {tx, ty}) when abs(x-tx)+abs(y-ty)==1, do: :adjacent
  defp relation(_, _), do: :distant
  defp action_outcome(a, p, p) when a in [:north,:south,:east,:west], do: :blocked
  defp action_outcome(a, _, _) when a in [:north,:south,:east,:west], do: :moved
  defp action_outcome(:wait, _, _), do: :waited
  defp action_outcome(_, _, _), do: :attempted_local_action
  defp bucket(v) when v < 0.25, do: :very_low
  defp bucket(v) when v < 0.50, do: :low
  defp bucket(v) when v < 0.75, do: :high
  defp bucket(_), do: :very_high
  defp bucket_cost(v) when v <= 0.0, do: :none
  defp bucket_cost(v) when v < 0.004, do: :low
  defp bucket_cost(v) when v < 0.008, do: :medium
  defp bucket_cost(_), do: :high
  defp trend(v) when v > 0.01, do: :rising
  defp trend(v) when v < -0.01, do: :falling
  defp trend(_), do: :stable
  defp fmt(v), do: :erlang.float_to_binary(v * 1.0, decimals: 3)
end