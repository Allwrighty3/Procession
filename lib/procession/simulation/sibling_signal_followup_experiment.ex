defmodule Procession.Simulation.SiblingSignalFollowupExperiment do
  @moduledoc """
  Factorial sibling-development diagnostic built on the original dependent
  development body, teacher, resource, and action mechanics.

  The only additions are a second simultaneous learner, optional peer perception
  and signaling, supervised OTP learner processes, and world-owned deadline ticks.
  """

  use GenServer

  alias Procession.Simulation.DevelopmentalField

  @conditions [
    :no_teacher_alone,
    :teacher_alone,
    :teacher_sibling_invisible,
    :teacher_sibling_visible,
    :teacher_sibling_signals,
    :no_teacher_sibling_visible,
    :no_teacher_sibling_signals
  ]
  @directions [:north, :south, :east, :west]
  @base_actions [:signal, :orient, :reach, :manipulate, :wait] ++ @directions
  @peer_signals [:signal_a, :signal_b]
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
    minimum_compression_gain: 2.0,
    output_learning_scale: 0.01
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 12)
    baby_ticks = Keyword.get(opts, :baby_ticks, 2_500)
    participation_ticks = Keyword.get(opts, :participation_ticks, 2_500)
    withdrawal_ticks = Keyword.get(opts, :withdrawal_ticks, 3_000)
    seed = Keyword.get(opts, :seed, 73)
    timeout = Keyword.get(opts, :intent_timeout_ms, 10)

    rows =
      for condition <- @conditions, pair <- 1..population do
        run_case(condition, pair, seed, baby_ticks, participation_ticks, withdrawal_ticks, timeout)
      end

    %{
      execution_model: :world_owned_deadline_ticks,
      population: population,
      baby_ticks: baby_ticks,
      participation_ticks: participation_ticks,
      withdrawal_ticks: withdrawal_ticks,
      learning_scale: 0.01,
      intent_timeout_ms: timeout,
      rows: rows,
      summary: summarize(rows)
    }
  end

  def report(result) do
    header = [
      "Dependent sibling factorial with restored baseline physics and teacher",
      "execution=#{result.execution_model}",
      "population=#{result.population} baby=#{result.baby_ticks} participation=#{result.participation_ticks} withdrawal=#{result.withdrawal_ticks}",
      "learning=#{result.learning_scale} intent_timeout_ms=#{result.intent_timeout_ms}"
    ]

    lines = Enum.map(@conditions, fn condition ->
      s = result.summary[condition]
      "#{condition}: baby=#{fmt(s.baby_survival_rate)} participation=#{fmt(s.participation_survival_rate)} " <>
        "withdrawal=#{fmt(s.withdrawal_survival_rate)} pair=#{fmt(s.pair_survival_rate)} " <>
        "self_intake=#{fmt(s.mean_self_intake)} caregiver=#{fmt(s.mean_caregiver_intake)} " <>
        "withdrawal_intake=#{fmt(s.mean_withdrawal_intake)} follow=#{fmt(s.follow_rate)} " <>
        "missed=#{fmt(s.missed_intent_rate)} signals=#{s.signal_attempts} useful=#{fmt(s.useful_signal_rate)}"
    end)

    Enum.join(header ++ lines, "\n")
  end

  defp run_case(condition, pair, seed, baby_ticks, participation_ticks, withdrawal_ticks, timeout) do
    {:ok, sup} = DynamicSupervisor.start_link(strategy: :one_for_one)
    ids = if sibling?(condition), do: [:a, :b], else: [:a]

    try do
      pids = Map.new(ids, fn id ->
        field_opts = Keyword.put(@field_opts, :encoding_salt, {:dependent_sibling, pair, id, seed})
        child = %{id: {__MODULE__, make_ref()}, start: {__MODULE__, :start_link, [[id: id, seed: learner_seed(seed, pair, id), field_opts: field_opts]]}, restart: :temporary}
        {:ok, pid} = DynamicSupervisor.start_child(sup, child)
        {id, pid}
      end)

      initial = %{
        resources: Map.new(Map.keys(@resources), &{&1, 0.80}),
        heard: %{a: nil, b: nil},
        accepted: 0,
        missed: 0,
        late: 0,
        follow: 0,
        opportunities: 0,
        signals: 0,
        audible: 0,
        useful: 0,
        phase_survival: %{baby: 0, participation: 0},
        records: []
      }

      total = baby_ticks + participation_ticks + withdrawal_ticks

      final = Enum.reduce(1..total, initial, fn tick, world ->
        phase = phase(tick, baby_ticks, participation_ticks)
        world = tick_world(pids, condition, phase, tick, world, timeout)

        phase_survival =
          cond do
            tick == baby_ticks -> Map.put(world.phase_survival, :baby, alive_count(pids))
            tick == baby_ticks + participation_ticks -> Map.put(world.phase_survival, :participation, alive_count(pids))
            true -> world.phase_survival
          end

        %{world | phase_survival: phase_survival}
      end)

      snapshots = Map.new(pids, fn {id, pid} -> {id, snapshot(pid)} end)
      alive = Enum.count(snapshots, fn {_id, s} -> s.alive? end)

      %{
        condition: condition,
        learner_count: length(ids),
        snapshots: snapshots,
        baby_survived: final.phase_survival.baby,
        participation_survived: final.phase_survival.participation,
        withdrawal_survived: alive,
        pair_survived?: alive == length(ids),
        accepted_intents: final.accepted,
        missed_intents: final.missed,
        late_intents: final.late,
        follow_events: final.follow,
        social_opportunities: final.opportunities,
        signal_attempts: final.signals,
        audible_signals: final.audible,
        useful_signals: final.useful,
        self_intake: Enum.sum(Enum.map(snapshots, fn {_id, s} -> s.self_intake end)),
        caregiver_intake: Enum.sum(Enum.map(snapshots, fn {_id, s} -> s.caregiver_intake end)),
        withdrawal_intake: Enum.sum(Enum.map(snapshots, fn {_id, s} -> s.withdrawal_intake end))
      }
    after
      if Process.alive?(sup), do: Supervisor.stop(sup)
    end
  end

  defp tick_world(pids, condition, phase, tick, world, timeout) do
    resources = regenerate(world.resources)
    states = Map.new(pids, fn {id, pid} -> {id, snapshot(pid)} end)
    social? = visible?(condition)
    signals? = signals?(condition)

    Enum.each(pids, fn {id, pid} ->
      state = states[id]
      other = other_state(states, id)
      features = perception(state, phase, resources, other, world.heard[id], social?, signals?)
      actions = allowed_actions(phase, signals?)
      cue = teacher_cue(condition, phase, state.position, resources, 1.0 - max(0.0, state.vitality - 0.014))
      request_intent(pid, self(), tick, features, actions, cue, phase)
    end)

    {intents, late} = collect_intents(tick, Map.keys(pids), timeout)
    before_distance = pair_distance(states)

    {resources, results} = Enum.reduce(Map.keys(pids), {resources, %{}}, fn id, {amounts, acc} ->
      state = states[id]
      action = get_in(intents, [id, :action]) || :wait
      {amounts, result} = resolve(state, action, condition, phase, amounts)
      :ok = commit(pids[id], action, result, phase)
      {amounts, Map.put(acc, id, %{action: action, result: result})}
    end)

    next_states = Map.new(pids, fn {id, pid} -> {id, snapshot(pid)} end)
    after_distance = pair_distance(next_states)
    approached = social? and before_distance != nil and after_distance < before_distance
    signals = Enum.count(results, fn {_id, r} -> r.action in @peer_signals end)
    audible = if signals? and before_distance != nil and before_distance <= 2, do: signals, else: 0
    useful = if approached and Enum.any?(results, fn {_id, r} -> r.action in @peer_signals end), do: 1, else: 0

    heard = %{
      a: peer_signal(results, :b),
      b: peer_signal(results, :a)
    }

    accepted = map_size(intents)
    expected = map_size(pids)

    %{
      world
      | resources: resources,
        heard: heard,
        accepted: world.accepted + accepted,
        missed: world.missed + expected - accepted,
        late: world.late + late,
        follow: world.follow + if(approached, do: 1, else: 0),
        opportunities: world.opportunities + if(social? and before_distance != nil and before_distance > 0, do: 1, else: 0),
        signals: world.signals + signals,
        audible: world.audible + audible,
        useful: world.useful + useful
    }
  end

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
  def snapshot(pid), do: GenServer.call(pid, :snapshot, :infinity)
  def request_intent(pid, owner, tick, features, actions, cue, phase), do: GenServer.cast(pid, {:intent, owner, tick, features, actions, cue, phase})
  def commit(pid, action, result, phase), do: GenServer.call(pid, {:commit, action, result, phase}, :infinity)

  @impl true
  def init(opts) do
    field_opts = Keyword.fetch!(opts, :field_opts)
    {:ok, %{
      id: Keyword.fetch!(opts, :id), seed: Keyword.fetch!(opts, :seed), field_opts: field_opts,
      field: DevelopmentalField.new(field_opts), position: {1, 1}, vitality: 0.60,
      fatigue: 0.0, intake: 0.0, caregiver_intake: 0.0, self_intake: 0.0,
      withdrawal_intake: 0.0, action_counts: Map.new(@base_actions ++ @peer_signals, &{&1, 0}),
      visited: MapSet.new([{1, 1}]), alive?: true, tick: 0, last_action: nil,
      last_caregiver: :none, records: []
    }}
  end

  @impl true
  def handle_cast({:intent, owner, tick, features, actions, cue, phase}, state) do
    field = DevelopmentalField.step(state.field, {:features, features}, state.field_opts)
    action = choose_action(%{state | field: field}, actions, cue, phase, tick)
    send(owner, {:dependent_sibling_intent, tick, state.id, action})
    {:noreply, %{state | field: field}}
  end

  @impl true
  def handle_call({:commit, action, result, phase}, _from, state) do
    record = %{tick: state.tick + 1, phase: phase, action: action, self_intake: result.self_intake, caregiver_intake: result.caregiver_intake, caregiver: result.caregiver_action}
    next = %{state |
      position: result.position, vitality: result.vitality, fatigue: result.fatigue,
      intake: state.intake + result.self_intake + result.caregiver_intake,
      caregiver_intake: state.caregiver_intake + result.caregiver_intake,
      self_intake: state.self_intake + result.self_intake,
      withdrawal_intake: state.withdrawal_intake + if(phase == :withdrawal, do: result.self_intake, else: 0.0),
      action_counts: Map.update(state.action_counts, action, 1, &(&1 + 1)),
      visited: MapSet.put(state.visited, result.position), alive?: result.vitality > 0.0,
      tick: state.tick + 1, last_action: action, last_caregiver: result.caregiver_action,
      records: [record | state.records]
    }
    {:reply, :ok, next}
  end

  def handle_call(:snapshot, _from, state), do: {:reply, Map.drop(state, [:field_opts, :field]), state}

  defp choose_action(state, actions, cue, phase, tick) do
    signature = sensory_signature(state.position)
    hunger = 1.0 - max(0.0, state.vitality - 0.014)

    actions
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({state.seed, tick, action}, 1_000) / 1_000 * exploration_gain(phase)
      baseline = baseline(action, phase, state.fatigue)
      pressure = if action == :wait, do: 0.0, else: hunger * pressure_gain(phase)
      object = if action in [:reach, :manipulate] and signature != :empty, do: 0.08, else: 0.0
      teaching = if action == cue, do: 0.34, else: 0.0
      learned = learned_motor_score(state.field, action, state.field_opts) * 0.40
      {action, exploration + baseline + pressure + object + teaching + learned}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp resolve(state, action, condition, phase, amounts) do
    depleted = max(0.0, state.vitality - 0.014)
    hunger = 1.0 - depleted
    {position, fatigue} = move(state.position, action, state.fatigue, phase)
    {amounts, self_intake} = interact(amounts, position, action, hunger, phase)
    teacher = teacher_mode(condition)
    {amounts, caregiver_intake, caregiver_action} = caregiver(teacher, phase, position, amounts, hunger, self_intake)
    vitality = min(1.0, depleted + self_intake + caregiver_intake)
    {amounts, %{position: position, fatigue: fatigue, vitality: vitality, self_intake: self_intake, caregiver_intake: caregiver_intake, caregiver_action: caregiver_action}}
  end

  defp perception(state, phase, resources, other, heard, social?, signals?) do
    base = [
      {:development_phase, phase}, {:body_channel, :vitality, bucket(state.vitality)},
      {:body_channel, :hunger, bucket(1.0 - state.vitality)}, {:body_channel, :fatigue, bucket(state.fatigue)},
      {:place_channel, state.position}, {:sensory_channel, sensory_signature(state.position)},
      {:caregiver_channel, state.last_caregiver}, {:motor_channel, state.last_action}
    ]

    social = if social? and other do
      [{:peer_bearing, direction_toward(state.position, other.position)}, {:peer_action, other.last_action}, {:peer_alive, other.alive?}, {:peer_signal, if(signals?, do: heard, else: nil)}, {:peer_resource_contact, Map.get(resources, other.position, 0.0) > 0.01}]
    else
      []
    end

    base ++ social
  end

  defp caregiver(:orphan, _phase, _position, amounts, _hunger, _self), do: {amounts, 0.0, :none}
  defp caregiver(_teacher, :withdrawal, _position, amounts, _hunger, _self), do: {amounts, 0.0, :none}
  defp caregiver(_teacher, _phase, _position, amounts, _hunger, self) when self > 0.0, do: {amounts, 0.0, :observe_success}
  defp caregiver(:participatory, :baby, _position, amounts, hunger, _self), do: direct_feed(amounts, hunger, :feed_and_expose)
  defp caregiver(:participatory, :participation, position, amounts, hunger, _self) do
    if hunger > 0.58, do: {Map.put(amounts, position, max(Map.get(amounts, position, 0.0), 0.20)), 0.0, :provision_for_participation}, else: {amounts, 0.0, :none}
  end

  defp direct_feed(amounts, hunger, action) do
    intake = if hunger > 0.38, do: min(0.20, hunger * 0.30), else: 0.0
    {amounts, intake, if(intake > 0.0, do: action, else: :none)}
  end

  defp teacher_cue(condition, :participation, position, amounts, hunger) do
    if teacher_mode(condition) == :participatory and hunger > 0.58 and Map.get(amounts, position, 0.0) > 0.01, do: :manipulate, else: :none
  end
  defp teacher_cue(_condition, _phase, _position, _amounts, _hunger), do: :none

  defp teacher_mode(condition) when condition in [:no_teacher_alone, :no_teacher_sibling_visible, :no_teacher_sibling_signals], do: :orphan
  defp teacher_mode(_condition), do: :participatory
  defp sibling?(condition), do: condition not in [:no_teacher_alone, :teacher_alone]
  defp visible?(condition), do: condition in [:teacher_sibling_visible, :teacher_sibling_signals, :no_teacher_sibling_visible, :no_teacher_sibling_signals]
  defp signals?(condition), do: condition in [:teacher_sibling_signals, :no_teacher_sibling_signals]

  defp allowed_actions(:baby, false), do: [:signal, :orient, :reach, :wait]
  defp allowed_actions(:baby, true), do: [:signal, :orient, :reach, :wait] ++ @peer_signals
  defp allowed_actions(_phase, false), do: @base_actions
  defp allowed_actions(_phase, true), do: @base_actions ++ @peer_signals

  defp collect_intents(tick, ids, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    collect_intents(tick, MapSet.new(ids), deadline, %{}, 0)
  end
  defp collect_intents(_tick, pending, _deadline, intents, late) when map_size(intents) > 0 and map_size(intents) == MapSet.size(pending) + map_size(intents), do: {intents, late}
  defp collect_intents(tick, pending, deadline, intents, late) do
    if MapSet.size(pending) == 0 do
      {intents, late}
    else
      remaining = max(deadline - System.monotonic_time(:millisecond), 0)
      receive do
        {:dependent_sibling_intent, ^tick, id, action} -> collect_intents(tick, MapSet.delete(pending, id), deadline, Map.put_new(intents, id, %{action: action}), late)
        {:dependent_sibling_intent, _other, _id, _action} -> collect_intents(tick, pending, deadline, intents, late + 1)
      after
        remaining -> {intents, late}
      end
    end
  end

  defp other_state(states, :a), do: Map.get(states, :b)
  defp other_state(states, :b), do: Map.get(states, :a)
  defp pair_distance(states) do
    case {Map.get(states, :a), Map.get(states, :b)} do
      {%{position: a}, %{position: b}} -> manhattan(a, b)
      _ -> nil
    end
  end
  defp peer_signal(results, id) do
    case Map.get(results, id) do
      %{action: action} when action in @peer_signals -> action
      _ -> nil
    end
  end

  defp phase(tick, baby, _participation) when tick <= baby, do: :baby
  defp phase(tick, baby, participation) when tick <= baby + participation, do: :participation
  defp phase(_tick, _baby, _participation), do: :withdrawal
  defp learner_seed(seed, pair, :a), do: seed + pair * 10_007 + 101
  defp learner_seed(seed, pair, :b), do: seed + pair * 10_007 + 503
  defp alive_count(pids), do: Enum.count(pids, fn {_id, pid} -> snapshot(pid).alive? end)

  defp move(position, action, fatigue, :baby) when action in @directions, do: {position, fatigue}
  defp move(position, :wait, fatigue, _phase), do: {position, max(0.0, fatigue - 0.07)}
  defp move(position, action, fatigue, _phase) when action in [:signal, :orient, :reach, :manipulate] ++ @peer_signals, do: {position, max(0.0, fatigue - 0.02)}
  defp move(position, direction, fatigue, _phase) when direction in @directions, do: {step(position, direction), min(1.0, fatigue + 0.045)}

  defp interact(amounts, position, action, hunger, phase) when action in [:reach, :manipulate] and phase != :baby do
    available = Map.get(amounts, position, 0.0)
    if available > 0.0 do
      intake = min(available, min(0.20, hunger * 0.30))
      {Map.put(amounts, position, available - intake), intake}
    else
      {amounts, 0.0}
    end
  end
  defp interact(amounts, _position, _action, _hunger, _phase), do: {amounts, 0.0}

  defp regenerate(amounts), do: Map.new(amounts, fn {position, amount} -> {position, min(0.80, amount + 0.010)} end)
  defp sensory_signature(position), do: Map.get(@resources, position, Map.get(@distractors, position, :empty))
  defp direction_toward({x, _y}, {tx, _ty}) when x < tx, do: :east
  defp direction_toward({x, _y}, {tx, _ty}) when x > tx, do: :west
  defp direction_toward({_x, y}, {_tx, ty}) when y < ty, do: :south
  defp direction_toward({_x, y}, {_tx, ty}) when y > ty, do: :north
  defp direction_toward(_position, _target), do: :here
  defp step({x, y}, :north), do: {x, max(0, y - 1)}
  defp step({x, y}, :south), do: {x, min(3, y + 1)}
  defp step({x, y}, :east), do: {min(3, x + 1), y}
  defp step({x, y}, :west), do: {max(0, x - 1), y}
  defp manhattan({x1, y1}, {x2, y2}), do: abs(x1 - x2) + abs(y1 - y2)

  defp learned_motor_score(field, action, opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_channel, action}, opts)
    Enum.reduce(field.activity, 0.0, fn {source, activity}, total ->
      if activity >= 0.18 do
        total + Enum.reduce(targets, 0.0, fn target, acc -> acc + Map.get(field.edges, {source, target}, 0.0) * activity end)
      else
        total
      end
    end)
  end

  defp exploration_gain(:baby), do: 0.12
  defp exploration_gain(_phase), do: 0.22
  defp pressure_gain(:baby), do: 0.12
  defp pressure_gain(:participation), do: 0.26
  defp pressure_gain(:withdrawal), do: 0.30
  defp baseline(:wait, :baby, fatigue), do: 0.36 + fatigue * 0.25
  defp baseline(:wait, _phase, fatigue), do: 0.27 + fatigue * 0.28
  defp baseline(:signal, :baby, _fatigue), do: 0.12
  defp baseline(_action, _phase, _fatigue), do: 0.0
  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_value), do: :very_high

  defp summarize(rows) do
    rows
    |> Enum.group_by(& &1.condition)
    |> Map.new(fn {condition, values} ->
      learners = Enum.sum(Enum.map(values, & &1.learner_count))
      expected = Enum.sum(Enum.map(values, &(&1.accepted_intents + &1.missed_intents)))
      attempts = Enum.sum(Enum.map(values, & &1.signal_attempts))
      {condition, %{
        baby_survival_rate: Enum.sum(Enum.map(values, & &1.baby_survived)) / max(learners, 1),
        participation_survival_rate: Enum.sum(Enum.map(values, & &1.participation_survived)) / max(learners, 1),
        withdrawal_survival_rate: Enum.sum(Enum.map(values, & &1.withdrawal_survived)) / max(learners, 1),
        pair_survival_rate: Enum.count(values, & &1.pair_survived?) / max(length(values), 1),
        mean_self_intake: Enum.sum(Enum.map(values, & &1.self_intake)) / max(learners, 1),
        mean_caregiver_intake: Enum.sum(Enum.map(values, & &1.caregiver_intake)) / max(learners, 1),
        mean_withdrawal_intake: Enum.sum(Enum.map(values, & &1.withdrawal_intake)) / max(learners, 1),
        follow_rate: Enum.sum(Enum.map(values, & &1.follow_events)) / max(Enum.sum(Enum.map(values, & &1.social_opportunities)), 1),
        missed_intent_rate: Enum.sum(Enum.map(values, & &1.missed_intents)) / max(expected, 1),
        late_intents: Enum.sum(Enum.map(values, & &1.late_intents)),
        signal_attempts: attempts,
        useful_signal_rate: Enum.sum(Enum.map(values, & &1.useful_signals)) / max(attempts, 1)
      }}
    end)
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
