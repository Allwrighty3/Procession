defmodule Procession.Simulation.DependentSurvivorAnalysisExperiment do
  @moduledoc """
  Replays the participatory condition from DependentDevelopmentExperiment with
  identical seeds and parameters, retaining per-entity trajectories so full
  withdrawal survivors can be compared with failures.
  """

  alias Procession.Simulation.DevelopmentalField

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

    runs =
      Enum.map(1..population, fn entity ->
        run_entity(total, baby_ticks, participation_ticks, seed, entity)
        |> trajectory(entity, baby_ticks, participation_ticks, total)
      end)

    survivors = Enum.filter(runs, & &1.survived)
    failures = Enum.reject(runs, & &1.survived)

    %{
      population: population,
      survivor_count: length(survivors),
      failure_count: length(failures),
      survivors: summarize(survivors),
      failures: summarize(failures),
      survivor_entities: Enum.map(survivors, & &1.entity),
      first_self_feed_entities: runs |> Enum.filter(&(&1.first_self_feed_tick != nil)) |> Enum.map(& &1.entity)
    }
  end

  def report(result) do
    [
      "Participatory survivor trajectory analysis",
      "population=#{result.population} survivors=#{result.survivor_count} failures=#{result.failure_count}",
      group_line(:survivors, result.survivors),
      group_line(:failures, result.failures),
      "survivor_entities=#{inspect(result.survivor_entities)}",
      "first_self_feed_entities=#{inspect(result.first_self_feed_entities)}"
    ]
    |> Enum.join("\n")
  end

  defp group_line(name, summary) do
    "#{name}: first_feed_rate=#{fmt(summary.first_feed_rate)} first_feed_tick=#{fmt(summary.median_first_feed_tick)} " <>
      "participation_self_intake=#{fmt(summary.median_participation_self_intake)} " <>
      "withdrawal_self_intake=#{fmt(summary.median_withdrawal_self_intake)} " <>
      "self_feed_events=#{fmt(summary.median_self_feed_events)} repeated_feeders=#{summary.repeated_feeders} " <>
      "pre_feed_manipulate=#{fmt(summary.pre_feed_manipulate_rate)} pre_feed_reach=#{fmt(summary.pre_feed_reach_rate)} " <>
      "pre_feed_move=#{fmt(summary.pre_feed_move_rate)} cells=#{fmt(summary.median_cells)} " <>
      "participation_actions=#{fmt(summary.median_participation_actions)} withdrawal_actions=#{fmt(summary.median_withdrawal_actions)} " <>
      "nodes=#{fmt(summary.median_nodes)} final_vitality=#{fmt(summary.median_final_vitality)}"
  end

  defp run_entity(total, baby_ticks, participation_ticks, seed, entity) do
    field_opts = Keyword.put(@field_opts, :encoding_salt, {:dependent_child, entity})

    initial = %{
      field: DevelopmentalField.new(field_opts),
      position: {1, 1},
      vitality: 0.60,
      fatigue: 0.0,
      resource_amounts: Map.new(Map.keys(@resources), &{&1, 0.80}),
      intake: 0.0,
      caregiver_intake: 0.0,
      self_intake: 0.0,
      action_counts: Map.new(@actions, &{&1, 0}),
      visited: MapSet.new([{1, 1}]),
      alive?: true,
      tick: 0,
      records: []
    }

    Enum.reduce_while(1..total, initial, fn tick, state ->
      next = advance(state, tick, baby_ticks, participation_ticks, seed + entity * 137, field_opts)
      if next.alive?, do: {:cont, next}, else: {:halt, next}
    end)
  end

  defp advance(state, tick, baby_ticks, participation_ticks, seed, field_opts) do
    phase = phase(tick, baby_ticks, participation_ticks)
    amounts = regenerate(state.resource_amounts)
    depleted = max(0.0, state.vitality - 0.014)
    hunger = 1.0 - depleted
    signature = sensory_signature(state.position)
    action = choose_action(state, phase, hunger, signature, tick, seed, field_opts)
    previous_position = state.position
    {position, fatigue} = move(state.position, action, state.fatigue, phase)
    {amounts, self_intake} = interact(amounts, position, action, hunger, phase)
    {amounts, caregiver_intake, caregiver_action} = caregiver(phase, position, amounts, hunger, self_intake)
    vitality = min(1.0, depleted + self_intake + caregiver_intake)

    features = [
      {:development_phase, phase},
      {:body_channel, :vitality, bucket(vitality)},
      {:body_channel, :hunger, bucket(hunger)},
      {:body_channel, :fatigue, bucket(fatigue)},
      {:place_channel, position},
      {:sensory_channel, signature},
      {:motor_channel, action},
      {:caregiver_channel, caregiver_action},
      {:self_intake_channel, self_intake > 0.0},
      {:caregiver_intake_channel, caregiver_intake > 0.0},
      {:change_channel, :vitality, trend(vitality - state.vitality)}
    ]

    field = DevelopmentalField.step(state.field, {:features, features}, field_opts)

    record = %{
      tick: tick,
      phase: phase,
      action: action,
      position: position,
      previous_position: previous_position,
      signature: signature,
      hunger: hunger,
      vitality_before: state.vitality,
      vitality_after: vitality,
      self_intake: self_intake,
      caregiver_intake: caregiver_intake,
      caregiver: caregiver_action
    }

    %{
      state
      | field: field,
        position: position,
        vitality: vitality,
        fatigue: fatigue,
        resource_amounts: amounts,
        intake: state.intake + self_intake + caregiver_intake,
        caregiver_intake: state.caregiver_intake + caregiver_intake,
        self_intake: state.self_intake + self_intake,
        action_counts: Map.update!(state.action_counts, action, &(&1 + 1)),
        visited: MapSet.put(state.visited, position),
        alive?: vitality > 0.0,
        tick: tick,
        records: [record | state.records]
    }
  end

  defp phase(tick, baby_ticks, _participation_ticks) when tick <= baby_ticks, do: :baby
  defp phase(tick, baby_ticks, participation_ticks) when tick <= baby_ticks + participation_ticks, do: :participation
  defp phase(_tick, _baby_ticks, _participation_ticks), do: :withdrawal

  defp caregiver(:withdrawal, _position, amounts, _hunger, _self_intake), do: {amounts, 0.0, :none}
  defp caregiver(_phase, _position, amounts, _hunger, self_intake) when self_intake > 0.0,
    do: {amounts, 0.0, :observe_success}
  defp caregiver(:baby, _position, amounts, hunger, _self_intake),
    do: direct_feed(amounts, hunger, :feed_and_expose)

  defp caregiver(:participation, position, amounts, hunger, _self_intake) do
    if hunger > 0.58 do
      placed = Map.put(amounts, position, max(Map.get(amounts, position, 0.0), 0.20))
      {placed, 0.0, :provision_for_participation}
    else
      {amounts, 0.0, :none}
    end
  end

  defp direct_feed(amounts, hunger, action) do
    intake = if hunger > 0.38, do: min(0.20, hunger * 0.30), else: 0.0
    {amounts, intake, if(intake > 0.0, do: action, else: :none)}
  end

  defp choose_action(state, phase, hunger, signature, tick, seed, field_opts) do
    allowed_actions(phase)
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * exploration_gain(phase)
      baseline = baseline(action, phase, state.fatigue)
      pressure = if action == :wait, do: 0.0, else: hunger * pressure_gain(phase)
      object = if action in [:reach, :manipulate] and signature != :empty, do: 0.08, else: 0.0
      learned = learned_motor_score(state.field, action, field_opts) * 0.40
      {action, exploration + baseline + pressure + object + learned}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

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
  defp regenerate(amounts), do: Map.new(amounts, fn {position, amount} -> {position, min(0.80, amount + 0.010)} end)
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

  defp trajectory(state, entity, baby_ticks, participation_ticks, total) do
    records = Enum.reverse(state.records)
    self_feeds = Enum.filter(records, &(&1.self_intake > 0.0))
    first_feed = List.first(self_feeds)
    previous = if first_feed, do: Enum.find(records, &(&1.tick == first_feed.tick - 1)), else: nil

    %{
      entity: entity,
      survived: state.alive? and state.tick == total,
      lifetime: state.tick,
      first_self_feed_tick: first_feed && first_feed.tick,
      first_self_feed_phase: first_feed && first_feed.phase,
      first_self_feed_action: first_feed && first_feed.action,
      first_self_feed_signature: first_feed && first_feed.signature,
      pre_feed_action: previous && previous.action,
      pre_feed_moved: previous && previous.position != previous.previous_position,
      self_feed_events: length(self_feeds),
      participation_self_intake: phase_sum(records, :participation, :self_intake),
      withdrawal_self_intake: phase_sum(records, :withdrawal, :self_intake),
      participation_actions: phase_actions(records, :participation),
      withdrawal_actions: phase_actions(records, :withdrawal),
      cells: MapSet.size(state.visited),
      nodes: MapSet.size(state.field.generated),
      final_vitality: state.vitality,
      baby_ticks: baby_ticks,
      participation_ticks: participation_ticks
    }
  end

  defp summarize([]) do
    %{first_feed_rate: 0.0, median_first_feed_tick: 0.0, median_participation_self_intake: 0.0,
      median_withdrawal_self_intake: 0.0, median_self_feed_events: 0.0, repeated_feeders: 0,
      pre_feed_manipulate_rate: 0.0, pre_feed_reach_rate: 0.0, pre_feed_move_rate: 0.0,
      median_cells: 0.0, median_participation_actions: 0.0, median_withdrawal_actions: 0.0,
      median_nodes: 0.0, median_final_vitality: 0.0}
  end

  defp summarize(runs) do
    feeders = Enum.filter(runs, &(&1.first_self_feed_tick != nil))
    %{
      first_feed_rate: length(feeders) / length(runs),
      median_first_feed_tick: median(Enum.map(feeders, &(&1.first_self_feed_tick * 1.0))),
      median_participation_self_intake: median(Enum.map(runs, & &1.participation_self_intake)),
      median_withdrawal_self_intake: median(Enum.map(runs, & &1.withdrawal_self_intake)),
      median_self_feed_events: median(Enum.map(runs, &(&1.self_feed_events * 1.0))),
      repeated_feeders: Enum.count(runs, &(&1.self_feed_events >= 2)),
      pre_feed_manipulate_rate: rate(feeders, &(&1.pre_feed_action == :manipulate)),
      pre_feed_reach_rate: rate(feeders, &(&1.pre_feed_action == :reach)),
      pre_feed_move_rate: rate(feeders, & &1.pre_feed_moved),
      median_cells: median(Enum.map(runs, &(&1.cells * 1.0))),
      median_participation_actions: median(Enum.map(runs, &(&1.participation_actions * 1.0))),
      median_withdrawal_actions: median(Enum.map(runs, &(&1.withdrawal_actions * 1.0))),
      median_nodes: median(Enum.map(runs, &(&1.nodes * 1.0))),
      median_final_vitality: median(Enum.map(runs, & &1.final_vitality))
    }
  end

  defp phase_sum(records, phase, key), do: records |> Enum.filter(&(&1.phase == phase)) |> Enum.reduce(0.0, &(Map.fetch!(&1, key) + &2))
  defp phase_actions(records, phase), do: Enum.count(records, &(&1.phase == phase and &1.action != :wait))
  defp rate([], _predicate), do: 0.0
  defp rate(values, predicate), do: Enum.count(values, predicate) / length(values)
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
