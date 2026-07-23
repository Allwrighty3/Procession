defmodule Procession.Simulation.SiblingPairSurvivalExperiment do
  @moduledoc """
  Sibling-only dependent-development experiment.

  Both learners decide from one immutable world snapshot. Their movement, resource
  intake, caregiver effects, and world changes are resolved together, preventing
  either learner from observing same-tick mutations caused by resolution order.
  """

  use GenServer

  alias Procession.Simulation.DevelopmentalField

  @conditions [
    :teacher_sibling_invisible,
    :teacher_sibling_visible,
    :teacher_sibling_signals,
    :no_teacher_sibling_visible,
    :no_teacher_sibling_signals
  ]
  @directions [:north, :south, :east, :west]
  @signals [:signal_a, :signal_b]
  @actions [:signal, :orient, :reach, :manipulate, :wait] ++ @directions
  @stationary [:signal, :orient, :reach, :manipulate, :signal_a, :signal_b]
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
    population = Keyword.get(opts, :population, 12)
    baby = Keyword.get(opts, :baby_ticks, 2_500)
    participation = Keyword.get(opts, :participation_ticks, 2_500)
    withdrawal = Keyword.get(opts, :withdrawal_ticks, 3_000)
    seed = Keyword.get(opts, :seed, 73)
    timeout = Keyword.get(opts, :intent_timeout_ms, 10)

    rows =
      for condition <- @conditions, pair <- 1..population do
        run_pair(condition, pair, seed, baby, participation, withdrawal, timeout)
      end

    %{
      execution_model: :simultaneous_world_snapshot_deadlines,
      population: population,
      baby_ticks: baby,
      participation_ticks: participation,
      withdrawal_ticks: withdrawal,
      learning_scale: 0.01,
      intent_timeout_ms: timeout,
      rows: rows,
      summary: summarize(rows)
    }
  end

  def report(result) do
    lines =
      Enum.map(@conditions, fn condition ->
        s = Map.fetch!(result.summary, condition)

        "#{condition}: baby=#{fmt(s.baby_survival_rate)} " <>
          "participation=#{fmt(s.participation_survival_rate)} " <>
          "withdrawal=#{fmt(s.withdrawal_survival_rate)} " <>
          "pair=#{fmt(s.pair_survival_rate)} " <>
          "self_intake=#{fmt(s.mean_self_intake)} " <>
          "caregiver=#{fmt(s.mean_caregiver_intake)} " <>
          "withdrawal_intake=#{fmt(s.mean_withdrawal_intake)} " <>
          "follow=#{fmt(s.follow_rate)} missed=#{fmt(s.missed_intent_rate)} " <>
          "signals=#{s.signal_attempts} useful=#{fmt(s.useful_signal_rate)}"
      end)

    [
      "Active sibling-only survival experiment",
      "execution=#{result.execution_model}",
      "population=#{result.population} baby=#{result.baby_ticks} participation=#{result.participation_ticks} withdrawal=#{result.withdrawal_ticks}",
      "learning=#{result.learning_scale} intent_timeout_ms=#{result.intent_timeout_ms}",
      "solo controls archived; all pair actions resolve from the same pre-tick world snapshot",
      ""
      | lines
    ]
    |> Enum.join("\n")
  end

  defp run_pair(condition, pair, seed, baby, participation, withdrawal, timeout) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)

    try do
      pids =
        Map.new([:a, :b], fn id ->
          learner_seed = seed + pair * 10_007 + if(id == :a, do: 101, else: 503)
          field_opts = Keyword.put(@field_opts, :encoding_salt, {:sibling_pair, pair, id, seed})

          spec = %{
            id: {__MODULE__, make_ref()},
            start: {__MODULE__, :start_link, [[id: id, seed: learner_seed, field_opts: field_opts]]},
            restart: :temporary
          }

          {:ok, pid} = DynamicSupervisor.start_child(supervisor, spec)
          {id, pid}
        end)

      total = baby + participation + withdrawal

      initial = %{
        resources: Map.new(Map.keys(@resources), &{&1, 0.80}),
        heard: %{a: nil, b: nil},
        accepted: 0,
        missed: 0,
        late: 0,
        follow: 0,
        opportunities: 0,
        signals: 0,
        useful: 0,
        baby_survived: 0,
        participation_survived: 0
      }

      final =
        Enum.reduce(1..total, initial, fn tick, world ->
          phase = phase(tick, baby, participation)
          world = tick_world(pids, condition, phase, tick, world, timeout)
          world = if tick == baby, do: %{world | baby_survived: alive_count(pids)}, else: world

          if tick == baby + participation,
            do: %{world | participation_survived: alive_count(pids)},
            else: world
        end)

      snapshots = Map.new(pids, fn {id, pid} -> {id, snapshot(pid)} end)
      alive = Enum.count(snapshots, fn {_id, state} -> state.alive? end)

      %{
        condition: condition,
        learner_count: 2,
        baby_survived: final.baby_survived,
        participation_survived: final.participation_survived,
        withdrawal_survived: alive,
        pair_survived?: alive == 2,
        accepted_intents: final.accepted,
        missed_intents: final.missed,
        late_intents: final.late,
        follow_events: final.follow,
        social_opportunities: final.opportunities,
        signal_attempts: final.signals,
        useful_signals: final.useful,
        self_intake: Enum.sum(Enum.map(snapshots, fn {_id, state} -> state.self_intake end)),
        caregiver_intake: Enum.sum(Enum.map(snapshots, fn {_id, state} -> state.caregiver_intake end)),
        withdrawal_intake: Enum.sum(Enum.map(snapshots, fn {_id, state} -> state.withdrawal_intake end))
      }
    after
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor)
    end
  end

  defp tick_world(pids, condition, phase, tick, world, timeout) do
    resources = regenerate(world.resources)
    states = Map.new(pids, fn {id, pid} -> {id, snapshot(pid)} end)
    social? = visible?(condition)
    signal_mode? = signals?(condition)

    Enum.each(pids, fn {id, pid} ->
      state = states[id]
      other = states[other_id(id)]
      features = perception(state, phase, resources, other, world.heard[id], social?, signal_mode?)
      actions = allowed_actions(phase, signal_mode?)
      GenServer.cast(pid, {:intent, self(), tick, features, actions, phase})
    end)

    deadline = System.monotonic_time(:millisecond) + timeout
    {intents, late} = collect_until(tick, MapSet.new([:a, :b]), deadline, %{}, 0)
    actions = Map.new([:a, :b], fn id -> {id, get_in(intents, [id, :action]) || :wait} end)
    before_distance = manhattan(states.a.position, states.b.position)

    proposals =
      Map.new([:a, :b], fn id ->
        state = states[id]
        action = actions[id]
        depleted = max(0.0, state.vitality - 0.014)
        hunger = 1.0 - depleted
        {position, fatigue} = move(state.position, action, state.fatigue, phase)
        desired = desired_intake(resources, position, action, hunger, phase)
        {id, %{position: position, fatigue: fatigue, depleted: depleted, hunger: hunger, desired: desired}}
      end)

    allocations = allocate_intake(resources, proposals)
    resources = consume_allocations(resources, proposals, allocations)

    {resources, outcomes} =
      Enum.reduce([:a, :b], {resources, %{}}, fn id, {amounts, acc} ->
        proposal = proposals[id]
        self_intake = allocations[id]

        {amounts, caregiver_intake, caregiver_action} =
          caregiver(teacher_mode(condition), phase, proposal.position, amounts, proposal.hunger, self_intake)

        vitality = min(1.0, proposal.depleted + self_intake + caregiver_intake)

        outcome = %{
          position: proposal.position,
          fatigue: proposal.fatigue,
          vitality: vitality,
          self_intake: self_intake,
          caregiver_intake: caregiver_intake,
          caregiver_action: caregiver_action
        }

        {amounts, Map.put(acc, id, outcome)}
      end)

    Enum.each([:a, :b], fn id ->
      :ok = GenServer.call(pids[id], {:commit, actions[id], outcomes[id], phase}, :infinity)
    end)

    next_states = Map.new(pids, fn {id, pid} -> {id, snapshot(pid)} end)
    after_distance = manhattan(next_states.a.position, next_states.b.position)
    approached? = social? and after_distance < before_distance
    signal_count = Enum.count(actions, fn {_id, action} -> action in @signals end)
    heard = %{a: peer_signal(actions, :b), b: peer_signal(actions, :a)}
    accepted = map_size(intents)

    %{
      world
      | resources: resources,
        heard: heard,
        accepted: world.accepted + accepted,
        missed: world.missed + 2 - accepted,
        late: world.late + late,
        follow: world.follow + if(approached?, do: 1, else: 0),
        opportunities: world.opportunities + if(social? and before_distance > 0, do: 1, else: 0),
        signals: world.signals + signal_count,
        useful: world.useful + if(approached? and signal_count > 0, do: 1, else: 0)
    }
  end

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
  def snapshot(pid), do: GenServer.call(pid, :snapshot, :infinity)

  @impl true
  def init(opts) do
    field_opts = Keyword.fetch!(opts, :field_opts)

    {:ok,
     %{
       id: Keyword.fetch!(opts, :id),
       seed: Keyword.fetch!(opts, :seed),
       field_opts: field_opts,
       field: DevelopmentalField.new(field_opts),
       position: {1, 1},
       vitality: 0.60,
       fatigue: 0.0,
       caregiver_intake: 0.0,
       self_intake: 0.0,
       withdrawal_intake: 0.0,
       alive?: true,
       tick: 0,
       last_action: nil,
       last_caregiver: :none
     }}
  end

  @impl true
  def handle_cast({:intent, owner, tick, features, actions, phase}, state) do
    learns? = rem(:erlang.phash2({:learn, state.seed, tick}, 10_000), 100) == 0

    field =
      if learns?,
        do: DevelopmentalField.step(state.field, {:features, features}, state.field_opts),
        else: state.field

    action = choose_action(%{state | field: field}, actions, phase, tick)
    send(owner, {:sibling_pair_intent, tick, state.id, action})
    {:noreply, %{state | field: field}}
  end

  @impl true
  def handle_call({:commit, action, outcome, phase}, _from, state) do
    next = %{
      state
      | position: outcome.position,
        vitality: outcome.vitality,
        fatigue: outcome.fatigue,
        caregiver_intake: state.caregiver_intake + outcome.caregiver_intake,
        self_intake: state.self_intake + outcome.self_intake,
        withdrawal_intake:
          state.withdrawal_intake + if(phase == :withdrawal, do: outcome.self_intake, else: 0.0),
        alive?: outcome.vitality > 0.0,
        tick: state.tick + 1,
        last_action: action,
        last_caregiver: outcome.caregiver_action
    }

    {:reply, :ok, next}
  end

  def handle_call(:snapshot, _from, state),
    do: {:reply, Map.drop(state, [:field_opts, :field]), state}

  defp choose_action(state, actions, phase, tick) do
    hunger = 1.0 - max(0.0, state.vitality - 0.014)
    signature = sensory_signature(state.position)

    actions
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({state.seed, tick, action}, 1_000) / 1_000 * exploration_gain(phase)
      baseline = baseline(action, phase, state.fatigue)
      pressure = if action == :wait, do: 0.0, else: hunger * pressure_gain(phase)
      object = if action in [:reach, :manipulate] and signature != :empty, do: 0.08, else: 0.0
      learned = learned_motor_score(state.field, action, state.field_opts) * 0.40
      {action, exploration + baseline + pressure + object + learned}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp perception(state, phase, resources, other, heard, social?, signal_mode?) do
    base = [
      {:development_phase, phase},
      {:body_channel, :vitality, bucket(state.vitality)},
      {:body_channel, :hunger, bucket(1.0 - state.vitality)},
      {:body_channel, :fatigue, bucket(state.fatigue)},
      {:place_channel, state.position},
      {:sensory_channel, sensory_signature(state.position)},
      {:motor_channel, state.last_action},
      {:caregiver_channel, state.last_caregiver}
    ]

    if social? do
      base ++
        [
          {:peer_bearing, direction_toward(state.position, other.position)},
          {:peer_action, other.last_action},
          {:peer_alive, other.alive?},
          {:peer_signal, if(signal_mode?, do: heard, else: nil)},
          {:peer_resource_contact, Map.get(resources, other.position, 0.0) > 0.01}
        ]
    else
      base
    end
  end

  defp collect_until(tick, pending, deadline, intents, late) do
    if MapSet.size(pending) == 0 do
      {intents, late}
    else
      remaining = max(deadline - System.monotonic_time(:millisecond), 0)

      receive do
        {:sibling_pair_intent, ^tick, id, action} ->
          collect_until(tick, MapSet.delete(pending, id), deadline, Map.put_new(intents, id, %{action: action}), late)

        {:sibling_pair_intent, _other_tick, _id, _action} ->
          collect_until(tick, pending, deadline, intents, late + 1)
      after
        remaining -> {intents, late}
      end
    end
  end

  defp desired_intake(amounts, position, action, hunger, phase)
       when action in [:reach, :manipulate] and phase != :baby do
    min(Map.get(amounts, position, 0.0), min(0.20, hunger * 0.30))
  end

  defp desired_intake(_amounts, _position, _action, _hunger, _phase), do: 0.0

  defp allocate_intake(resources, proposals) do
    Enum.reduce([:a, :b], %{a: 0.0, b: 0.0}, fn id, allocations ->
      proposal = proposals[id]
      peer = proposals[other_id(id)]

      cond do
        proposal.desired <= 0.0 -> allocations
        proposal.position != peer.position or peer.desired <= 0.0 -> Map.put(allocations, id, proposal.desired)
        id == :b -> allocations
        true ->
          available = Map.get(resources, proposal.position, 0.0)
          total_desired = proposal.desired + peer.desired
          scale = min(1.0, available / max(total_desired, 0.000_001))
          allocations
          |> Map.put(:a, proposal.desired * scale)
          |> Map.put(:b, peer.desired * scale)
      end
    end)
  end

  defp consume_allocations(resources, proposals, allocations) do
    Enum.reduce([:a, :b], resources, fn id, amounts ->
      amount = allocations[id]
      position = proposals[id].position
      if amount > 0.0, do: Map.update!(amounts, position, &max(0.0, &1 - amount)), else: amounts
    end)
  end

  defp caregiver(:orphan, _phase, _position, amounts, _hunger, _self), do: {amounts, 0.0, :none}
  defp caregiver(_teacher, :withdrawal, _position, amounts, _hunger, _self), do: {amounts, 0.0, :none}
  defp caregiver(_teacher, _phase, _position, amounts, _hunger, self) when self > 0.0,
    do: {amounts, 0.0, :observe_success}

  defp caregiver(:participatory, :baby, _position, amounts, hunger, _self),
    do: direct_feed(amounts, hunger, :feed_and_expose)

  defp caregiver(:participatory, :participation, position, amounts, hunger, _self) do
    if hunger > 0.58,
      do: {Map.put(amounts, position, max(Map.get(amounts, position, 0.0), 0.20)), 0.0, :provision_for_participation},
      else: {amounts, 0.0, :none}
  end

  defp direct_feed(amounts, hunger, action) do
    intake = if hunger > 0.38, do: min(0.20, hunger * 0.30), else: 0.0
    {amounts, intake, if(intake > 0.0, do: action, else: :none)}
  end

  defp teacher_mode(condition) when condition in [:no_teacher_sibling_visible, :no_teacher_sibling_signals], do: :orphan
  defp teacher_mode(_condition), do: :participatory
  defp visible?(:teacher_sibling_invisible), do: false
  defp visible?(_condition), do: true
  defp signals?(condition), do: condition in [:teacher_sibling_signals, :no_teacher_sibling_signals]

  defp allowed_actions(:baby, false), do: [:signal, :orient, :reach, :wait]
  defp allowed_actions(:baby, true), do: [:signal, :orient, :reach, :wait] ++ @signals
  defp allowed_actions(_phase, false), do: @actions
  defp allowed_actions(_phase, true), do: @actions ++ @signals

  defp phase(tick, baby, _participation) when tick <= baby, do: :baby
  defp phase(tick, baby, participation) when tick <= baby + participation, do: :participation
  defp phase(_tick, _baby, _participation), do: :withdrawal
  defp alive_count(pids), do: Enum.count(pids, fn {_id, pid} -> snapshot(pid).alive? end)
  defp other_id(:a), do: :b
  defp other_id(:b), do: :a

  defp peer_signal(actions, id) do
    case Map.get(actions, id) do
      action when action in @signals -> action
      _ -> nil
    end
  end

  defp move(position, action, fatigue, :baby) when action in @directions, do: {position, fatigue}
  defp move(position, :wait, fatigue, _phase), do: {position, max(0.0, fatigue - 0.07)}
  defp move(position, action, fatigue, _phase) when action in @stationary,
    do: {position, max(0.0, fatigue - 0.02)}
  defp move(position, direction, fatigue, _phase) when direction in @directions,
    do: {step(position, direction), min(1.0, fatigue + 0.045)}

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

      {condition,
       %{
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
