defmodule Procession.Simulation.PrimitiveDevelopmentExperiment do
  @moduledoc """
  Developmental sibling experiment whose learners select body-level controls rather
  than semantic actions.

  The selectable controls are translation activation, limb extension/contraction,
  raw phonation, and relaxation. Contact, feeding, approaching, following, and
  communication are observer interpretations of trajectories and consequences.

  General substrate supplied by the simulation:

    * persistent homeostatic pressure;
    * proprioceptive and exteroceptive consequences;
    * salience-modulated plasticity on every experienced tick;
    * bounded structured episodic traces;
    * learned action/outcome predictions and prediction error;
    * learned context/control value from homeostatic change.

  No signal meaning, feeding policy, reaching policy, or peer-following policy is
  inserted into the learner.
  """

  use GenServer

  alias Procession.Simulation.DevelopmentalField

  @conditions [
    :teacher_pair_invisible,
    :teacher_pair_visible,
    :teacher_pair_audible,
    :orphan_pair_visible,
    :orphan_pair_audible
  ]

  @controls [
    :translate_x_positive,
    :translate_x_negative,
    :translate_y_positive,
    :translate_y_negative,
    :extend_limb,
    :contract_limb,
    :phonate_low,
    :phonate_high,
    :relax
  ]

  @phonation_controls [:phonate_low, :phonate_high]
  @translation_controls [
    :translate_x_positive,
    :translate_x_negative,
    :translate_y_positive,
    :translate_y_negative
  ]

  @resources %{
    {0, 0} => :rough_cool,
    {3, 0} => :sweet_soft,
    {2, 3} => :sharp_dry
  }

  @distractors %{
    {1, 0} => :rough_cool,
    {0, 2} => :sweet_soft,
    {3, 2} => :sharp_dry,
    {1, 3} => :smooth_warm
  }

  @field_opts [
    micro_nodes: 128,
    input_width: 3,
    consolidation_threshold: 4,
    coherence_threshold: 0.06,
    reuse_threshold: 0.50,
    edge_retention: 0.9995,
    activity_retention: 0.72,
    plasticity_fanout: 6,
    minimum_compression_gain: 2.0
  ]

  def controls, do: @controls

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
      execution_model: :simultaneous_primitive_body_deadlines,
      action_level: :body_control_primitives,
      controls: @controls,
      population: population,
      baby_ticks: baby,
      participation_ticks: participation,
      withdrawal_ticks: withdrawal,
      rows: rows,
      summary: summarize(rows)
    }
  end

  def report(result) do
    header = [
      "Primitive developmental sibling experiment",
      "execution=#{result.execution_model}",
      "action_level=#{result.action_level}",
      "controls=#{Enum.join(Enum.map(result.controls, &Atom.to_string/1), ",")}",
      "population=#{result.population} baby=#{result.baby_ticks} participation=#{result.participation_ticks} withdrawal=#{result.withdrawal_ticks}",
      "named behaviors are observer diagnostics; learners receive no reach/feed/follow/signal action tokens",
      ""
    ]

    lines =
      Enum.map(@conditions, fn condition ->
        s = Map.fetch!(result.summary, condition)

        "#{condition}: baby=#{fmt(s.baby_survival_rate)} " <>
          "participation=#{fmt(s.participation_survival_rate)} " <>
          "withdrawal=#{fmt(s.withdrawal_survival_rate)} pair=#{fmt(s.pair_survival_rate)} " <>
          "self_intake=#{fmt(s.mean_self_intake)} withdrawal_intake=#{fmt(s.mean_withdrawal_intake)} " <>
          "contacts=#{fmt(s.mean_contacts)} feed_sequences=#{fmt(s.mean_feed_sequences)} " <>
          "phonations=#{fmt(s.mean_phonations)} peer_responses=#{fmt(s.mean_peer_responses)} " <>
          "plasticity=#{fmt(s.mean_plasticity)} surprise=#{fmt(s.mean_surprise)} " <>
          "episodes=#{fmt(s.mean_episode_count)} missed=#{fmt(s.missed_intent_rate)}"
      end)

    Enum.join(header ++ lines, "\n")
  end

  defp run_pair(condition, pair, seed, baby, participation, withdrawal, timeout) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)

    try do
      pids =
        Map.new([:a, :b], fn id ->
          learner_seed = seed + pair * 10_007 + if(id == :a, do: 101, else: 503)
          field_opts = Keyword.put(@field_opts, :encoding_salt, {:primitive_body, pair, id, seed})

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
        sounds: %{a: nil, b: nil},
        accepted: 0,
        missed: 0,
        late: 0,
        baby_survived: 0,
        participation_survived: 0,
        peer_responses: 0
      }

      final =
        Enum.reduce(1..total, initial, fn tick, world ->
          stage = stage(tick, baby, participation)
          world = tick_world(pids, condition, stage, tick, world, timeout)
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
        peer_responses: final.peer_responses,
        self_intake: sum_snapshot(snapshots, :self_intake),
        caregiver_intake: sum_snapshot(snapshots, :caregiver_intake),
        withdrawal_intake: sum_snapshot(snapshots, :withdrawal_intake),
        contacts: sum_snapshot(snapshots, :contacts),
        feed_sequences: sum_snapshot(snapshots, :feed_sequences),
        phonations: sum_snapshot(snapshots, :phonations),
        plasticity_total: sum_snapshot(snapshots, :plasticity_total),
        surprise_total: sum_snapshot(snapshots, :surprise_total),
        learned_ticks: sum_snapshot(snapshots, :learned_ticks),
        episode_count: sum_snapshot(snapshots, :episode_count)
      }
    after
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor)
    end
  end

  defp tick_world(pids, condition, stage, tick, world, timeout) do
    resources = regenerate(world.resources)
    states = Map.new(pids, fn {id, pid} -> {id, snapshot(pid)} end)
    visible? = visible?(condition)
    audible? = audible?(condition)

    teacher_events =
      Map.new([:a, :b], fn id ->
        teacher_event(teacher?(condition), stage, states[id], resources)
        |> then(&{id, &1})
      end)

    Enum.each([:a, :b], fn id ->
      state = states[id]
      other = states[other_id(id)]

      sensory =
        sensory_frame(
          state,
          other,
          resources,
          world.sounds[id],
          teacher_events[id].sound,
          visible?,
          audible?
        )

      GenServer.cast(pids[id], {:intent, self(), tick, sensory, @controls})
    end)

    deadline = System.monotonic_time(:millisecond) + timeout
    {intents, late} = collect_until(tick, MapSet.new([:a, :b]), deadline, %{}, 0)
    controls = Map.new([:a, :b], fn id -> {id, get_in(intents, [id, :control]) || :relax} end)

    proposals =
      Map.new([:a, :b], fn id ->
        state = states[id]
        control = controls[id]
        depleted = max(0.0, state.vitality - 0.014)
        body = apply_control(state, control, stage)
        local_amount = Map.get(resources, body.position, 0.0)
        contact? = body.limb_extension >= 0.60 and local_amount > 0.01

        desired =
          if control == :contract_limb and state.contact? and stage != :baby do
            min(local_amount, min(0.20, (1.0 - depleted) * 0.30))
          else
            0.0
          end

        {id,
         %{
           position: body.position,
           limb_extension: body.limb_extension,
           fatigue: body.fatigue,
           depleted: depleted,
           contact?: contact?,
           desired: desired
         }}
      end)

    allocations = allocate_intake(resources, proposals)
    resources = consume_allocations(resources, proposals, allocations)

    {resources, outcomes} =
      Enum.reduce([:a, :b], {resources, %{}}, fn id, {amounts, acc} ->
        proposal = proposals[id]
        event = teacher_events[id]
        self_intake = allocations[id]

        {amounts, caregiver_intake} =
          apply_teacher_event(event, proposal.position, amounts, 1.0 - proposal.depleted, self_intake)

        outcome = %{
          position: proposal.position,
          limb_extension: proposal.limb_extension,
          fatigue: proposal.fatigue,
          contact?: proposal.contact?,
          vitality: min(1.0, proposal.depleted + self_intake + caregiver_intake),
          self_intake: self_intake,
          caregiver_intake: caregiver_intake,
          sensory_change?: sensory_signature(states[id].position) != sensory_signature(proposal.position),
          peer_changed?: controls[other_id(id)] != :relax
        }

        {amounts, Map.put(acc, id, outcome)}
      end)

    Enum.each([:a, :b], fn id ->
      :ok = GenServer.call(pids[id], {:commit, controls[id], outcomes[id], stage}, :infinity)
    end)

    sounds =
      Map.new([:a, :b], fn id ->
        peer_control = controls[other_id(id)]
        sound = if audible? and peer_control in @phonation_controls, do: raw_sound(peer_control), else: nil
        {id, sound}
      end)

    peer_responses =
      Enum.count([:a, :b], fn id ->
        heard? = world.sounds[id] != nil
        moved? = controls[id] in @translation_controls
        heard? and moved?
      end)

    accepted = map_size(intents)

    %{
      world
      | resources: resources,
        sounds: sounds,
        accepted: world.accepted + accepted,
        missed: world.missed + 2 - accepted,
        late: world.late + late,
        peer_responses: world.peer_responses + peer_responses
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
       limb_extension: 0.0,
       contact?: false,
       vitality: 0.60,
       fatigue: 0.0,
       alive?: true,
       last_control: :relax,
       last_outcome: :none,
       predictions: %{},
       values: %{},
       episodes: [],
       self_intake: 0.0,
       caregiver_intake: 0.0,
       withdrawal_intake: 0.0,
       contacts: 0,
       feed_sequences: 0,
       phonations: 0,
       plasticity_total: 0.0,
       surprise_total: 0.0,
       learned_ticks: 0,
       tick: 0
     }}
  end

  @impl true
  def handle_cast({:intent, owner, tick, sensory, controls}, state) do
    context = context_key(sensory)
    control = choose_control(state, context, controls, tick)
    send(owner, {:primitive_intent, tick, state.id, control})
    {:noreply, Map.put(state, :pending_sensory, sensory)}
  end

  @impl true
  def handle_call({:commit, control, outcome, stage}, _from, state) do
    sensory = Map.get(state, :pending_sensory, [])
    context = context_key(sensory)
    outcome_key = outcome_key(outcome)
    surprise = prediction_error(state.predictions, {context, control}, outcome_key)
    homeostatic_change = max(0.0, outcome.vitality - state.vitality)
    novelty = novelty(state.episodes, context)
    arousal = min(1.0, 1.0 - state.vitality)
    plasticity = plasticity_level(surprise, homeostatic_change, novelty, arousal)

    field_opts = Keyword.put(state.field_opts, :plasticity_budget, 0.08 * plasticity)

    learning_frame =
      {:features,
       sensory ++
         [
           {:body_control, control},
           {:proprioception_after, bucket(outcome.limb_extension)},
           {:contact_after, outcome.contact?},
           {:homeostatic_delta, bucket(homeostatic_change)},
           {:prediction_error, bucket(surprise)}
         ]}

    field = DevelopmentalField.step(state.field, learning_frame, field_opts)
    predictions = update_prediction(state.predictions, {context, control}, outcome_key)
    value = homeostatic_change - control_cost(control, outcome.fatigue)
    values = update_value(state.values, {context, control}, value, plasticity)

    episode = %{
      tick: state.tick,
      context: context,
      control: control,
      outcome: outcome_key,
      need_before: bucket(1.0 - state.vitality),
      need_after: bucket(1.0 - outcome.vitality),
      surprise: surprise,
      plasticity: plasticity
    }

    episodes = [episode | state.episodes] |> Enum.take(12)

    next = %{
      state
      | field: field,
        position: outcome.position,
        limb_extension: outcome.limb_extension,
        contact?: outcome.contact?,
        vitality: outcome.vitality,
        fatigue: outcome.fatigue,
        alive?: outcome.vitality > 0.0,
        last_control: control,
        last_outcome: outcome_key,
        predictions: predictions,
        values: values,
        episodes: episodes,
        self_intake: state.self_intake + outcome.self_intake,
        caregiver_intake: state.caregiver_intake + outcome.caregiver_intake,
        withdrawal_intake:
          state.withdrawal_intake + if(stage == :withdrawal, do: outcome.self_intake, else: 0.0),
        contacts: state.contacts + if(outcome.contact?, do: 1, else: 0),
        feed_sequences:
          state.feed_sequences + if(control == :contract_limb and outcome.self_intake > 0.0, do: 1, else: 0),
        phonations: state.phonations + if(control in @phonation_controls, do: 1, else: 0),
        plasticity_total: state.plasticity_total + plasticity,
        surprise_total: state.surprise_total + surprise,
        learned_ticks: state.learned_ticks + 1,
        tick: state.tick + 1
    }

    {:reply, :ok, Map.delete(next, :pending_sensory)}
  end

  def handle_call(:snapshot, _from, state) do
    public =
      state
      |> Map.drop([:field_opts, :field, :predictions, :values, :episodes, :pending_sensory])
      |> Map.put(:episode_count, length(state.episodes))

    {:reply, public, state}
  end

  defp choose_control(state, context, controls, tick) do
    hunger = 1.0 - state.vitality

    controls
    |> Enum.map(fn control ->
      exploration = :erlang.phash2({state.seed, tick, control}, 10_000) / 10_000 * exploration_gain(state.tick)
      learned_value = Map.get(state.values, {context, control}, 0.0) * 1.8
      motor_support = learned_motor_score(state.field, control, state.field_opts) * 0.35
      persistence = if hunger > 0.45 and state.last_control == control, do: 0.08 * hunger, else: 0.0
      fatigue_cost = control_cost(control, state.fatigue)
      {control, exploration + learned_value + motor_support + persistence - fatigue_cost}
    end)
    |> Enum.max_by(fn {control, score} -> {score, control} end)
    |> elem(0)
  end

  defp sensory_frame(state, other, resources, peer_sound, teacher_sound, visible?, audible?) do
    base = [
      {:body_vitality, bucket(state.vitality)},
      {:body_hunger, bucket(1.0 - state.vitality)},
      {:body_fatigue, bucket(state.fatigue)},
      {:proprioception_extension, bucket(state.limb_extension)},
      {:tactile_contact, state.contact?},
      {:local_signature, sensory_signature(state.position)},
      {:local_amount, bucket(Map.get(resources, state.position, 0.0))},
      {:last_body_control, state.last_control},
      {:last_outcome, state.last_outcome},
      {:teacher_sound, teacher_sound}
    ]

    base = if audible?, do: [{:ambient_sound, peer_sound} | base], else: base

    if visible? do
      {dx, dy} = relative_displacement(state.position, other.position)

      [
        {:moving_form_dx, signed_bucket(dx)},
        {:moving_form_dy, signed_bucket(dy)},
        {:moving_form_control, other.last_control},
        {:moving_form_contact, other.contact?}
        | base
      ]
    else
      base
    end
  end

  defp context_key(sensory) do
    sensory
    |> Enum.filter(fn
      {:body_hunger, _} -> true
      {:body_fatigue, _} -> true
      {:proprioception_extension, _} -> true
      {:tactile_contact, _} -> true
      {:local_signature, _} -> true
      {:local_amount, _} -> true
      {:ambient_sound, _} -> true
      {:moving_form_dx, _} -> true
      {:moving_form_dy, _} -> true
      _ -> false
    end)
    |> Enum.sort()
    |> List.to_tuple()
  end

  defp apply_control(state, control, :baby) when control in @translation_controls do
    %{position: state.position, limb_extension: state.limb_extension, fatigue: state.fatigue}
  end

  defp apply_control(state, :translate_x_positive, _stage), do: moved(state, {1, 0})
  defp apply_control(state, :translate_x_negative, _stage), do: moved(state, {-1, 0})
  defp apply_control(state, :translate_y_positive, _stage), do: moved(state, {0, 1})
  defp apply_control(state, :translate_y_negative, _stage), do: moved(state, {0, -1})

  defp apply_control(state, :extend_limb, _stage) do
    %{
      position: state.position,
      limb_extension: min(1.0, state.limb_extension + 0.25),
      fatigue: min(1.0, state.fatigue + 0.02)
    }
  end

  defp apply_control(state, :contract_limb, _stage) do
    %{
      position: state.position,
      limb_extension: max(0.0, state.limb_extension - 0.30),
      fatigue: min(1.0, state.fatigue + 0.015)
    }
  end

  defp apply_control(state, control, _stage) when control in @phonation_controls do
    %{
      position: state.position,
      limb_extension: state.limb_extension,
      fatigue: min(1.0, state.fatigue + 0.008)
    }
  end

  defp apply_control(state, :relax, _stage) do
    %{
      position: state.position,
      limb_extension: max(0.0, state.limb_extension - 0.05),
      fatigue: max(0.0, state.fatigue - 0.07)
    }
  end

  defp moved(state, {dx, dy}) do
    {x, y} = state.position

    %{
      position: {clamp_int(x + dx, 0, 3), clamp_int(y + dy, 0, 3)},
      limb_extension: state.limb_extension,
      fatigue: min(1.0, state.fatigue + 0.045)
    }
  end

  defp teacher_event(false, _stage, _state, _resources), do: %{kind: :none, sound: nil}
  defp teacher_event(true, :withdrawal, _state, _resources), do: %{kind: :none, sound: nil}

  defp teacher_event(true, :baby, state, _resources) do
    if 1.0 - max(0.0, state.vitality - 0.014) > 0.38,
      do: %{kind: :direct_regulation, sound: {:pulse, :low, :short}},
      else: %{kind: :presence, sound: {:pulse, :low, :soft}}
  end

  defp teacher_event(true, :participation, state, resources) do
    hunger = 1.0 - max(0.0, state.vitality - 0.014)

    cond do
      hunger <= 0.58 -> %{kind: :presence, sound: {:pulse, :low, :soft}}
      Map.get(resources, state.position, 0.0) > 0.01 -> %{kind: :presence, sound: {:pulse, :high, :short}}
      true -> %{kind: :provision, sound: {:pulse, :high, :long}}
    end
  end

  defp apply_teacher_event(%{kind: :direct_regulation}, _position, resources, hunger, _self) do
    intake = if hunger > 0.38, do: min(0.20, hunger * 0.30), else: 0.0
    {resources, intake}
  end

  defp apply_teacher_event(%{kind: :provision}, position, resources, hunger, self_intake) do
    resources =
      if hunger > 0.58 and self_intake <= 0.0,
        do: Map.put(resources, position, max(Map.get(resources, position, 0.0), 0.20)),
        else: resources

    {resources, 0.0}
  end

  defp apply_teacher_event(_event, _position, resources, _hunger, _self), do: {resources, 0.0}

  defp plasticity_level(surprise, homeostatic_change, novelty, arousal) do
    clamp_float(
      0.05 + surprise * 0.30 + min(homeostatic_change * 4.0, 1.0) * 0.30 + novelty * 0.20 + arousal * 0.15,
      0.05,
      1.0
    )
  end

  defp prediction_error(predictions, key, outcome) do
    counts = Map.get(predictions, key, %{})
    total = Enum.sum(Map.values(counts))
    probability = (Map.get(counts, outcome, 0) + 1.0) / (total + max(map_size(counts), 1) + 1.0)
    1.0 - probability
  end

  defp update_prediction(predictions, key, outcome) do
    Map.update(predictions, key, %{outcome => 1}, fn counts ->
      Map.update(counts, outcome, 1, &(&1 + 1))
    end)
  end

  defp update_value(values, key, observed, plasticity) do
    Map.update(values, key, observed, fn previous ->
      previous + plasticity * 0.20 * (observed - previous)
    end)
  end

  defp novelty(episodes, context) do
    occurrences = Enum.count(episodes, &(&1.context == context))
    1.0 / (1.0 + occurrences)
  end

  defp outcome_key(outcome) do
    {
      :outcome,
      bucket(outcome.self_intake),
      bucket(outcome.caregiver_intake),
      outcome.contact?,
      outcome.sensory_change?,
      outcome.peer_changed?
    }
  end

  defp control_cost(control, fatigue) when control in @translation_controls, do: 0.018 + fatigue * 0.025
  defp control_cost(control, fatigue) when control in @phonation_controls, do: 0.004 + fatigue * 0.004
  defp control_cost(:extend_limb, fatigue), do: 0.010 + fatigue * 0.010
  defp control_cost(:contract_limb, fatigue), do: 0.008 + fatigue * 0.008
  defp control_cost(:relax, _fatigue), do: 0.0

  defp learned_motor_score(field, control, opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:body_control, control}, opts)

    Enum.reduce(field.activity, 0.0, fn {source, activity}, total ->
      if activity >= 0.18 do
        total + Enum.reduce(targets, 0.0, fn target, acc -> acc + Map.get(field.edges, {source, target}, 0.0) * activity end)
      else
        total
      end
    end)
  end

  defp collect_until(tick, pending, deadline, intents, late) do
    if MapSet.size(pending) == 0 do
      {intents, late}
    else
      remaining = max(deadline - System.monotonic_time(:millisecond), 0)

      receive do
        {:primitive_intent, ^tick, id, control} ->
          collect_until(tick, MapSet.delete(pending, id), deadline, Map.put_new(intents, id, %{control: control}), late)

        {:primitive_intent, _other_tick, _id, _control} ->
          collect_until(tick, pending, deadline, intents, late + 1)
      after
        remaining -> {intents, late}
      end
    end
  end

  defp allocate_intake(resources, proposals) do
    a = proposals.a
    b = proposals.b

    if a.position == b.position and a.desired > 0.0 and b.desired > 0.0 do
      available = Map.get(resources, a.position, 0.0)
      scale = min(1.0, available / max(a.desired + b.desired, 0.000_001))
      %{a: a.desired * scale, b: b.desired * scale}
    else
      %{a: a.desired, b: b.desired}
    end
  end

  defp consume_allocations(resources, proposals, allocations) do
    Enum.reduce([:a, :b], resources, fn id, amounts ->
      amount = allocations[id]
      position = proposals[id].position
      if amount > 0.0, do: Map.update!(amounts, position, &max(0.0, &1 - amount)), else: amounts
    end)
  end

  defp regenerate(amounts),
    do: Map.new(amounts, fn {position, amount} -> {position, min(0.80, amount + 0.010)} end)

  defp raw_sound(:phonate_low), do: {:wave, :low, :brief}
  defp raw_sound(:phonate_high), do: {:wave, :high, :brief}

  defp sensory_signature(position),
    do: Map.get(@resources, position, Map.get(@distractors, position, :empty))

  defp relative_displacement({x, y}, {other_x, other_y}), do: {other_x - x, other_y - y}

  defp stage(tick, baby, _participation) when tick <= baby, do: :baby
  defp stage(tick, baby, participation) when tick <= baby + participation, do: :participation
  defp stage(_tick, _baby, _participation), do: :withdrawal

  defp teacher?(condition), do: condition in [:teacher_pair_invisible, :teacher_pair_visible, :teacher_pair_audible]
  defp visible?(:teacher_pair_invisible), do: false
  defp visible?(_condition), do: true
  defp audible?(condition), do: condition in [:teacher_pair_audible, :orphan_pair_audible]

  defp other_id(:a), do: :b
  defp other_id(:b), do: :a

  defp alive_count(pids), do: Enum.count(pids, fn {_id, pid} -> snapshot(pid).alive? end)
  defp sum_snapshot(snapshots, key), do: Enum.sum(Enum.map(snapshots, fn {_id, state} -> Map.fetch!(state, key) end))

  defp exploration_gain(tick) when tick < 2_500, do: 0.35
  defp exploration_gain(_tick), do: 0.22

  defp signed_bucket(value) when value < -1, do: :far_negative
  defp signed_bucket(-1), do: :near_negative
  defp signed_bucket(0), do: :zero
  defp signed_bucket(1), do: :near_positive
  defp signed_bucket(_value), do: :far_positive

  defp bucket(value) when is_boolean(value), do: value
  defp bucket(value) when value < 0.10, do: :minimal
  defp bucket(value) when value < 0.30, do: :low
  defp bucket(value) when value < 0.60, do: :medium
  defp bucket(value) when value < 0.85, do: :high
  defp bucket(_value), do: :very_high

  defp clamp_int(value, low, high), do: value |> max(low) |> min(high)
  defp clamp_float(value, low, high), do: value |> max(low) |> min(high)

  defp summarize(rows) do
    rows
    |> Enum.group_by(& &1.condition)
    |> Map.new(fn {condition, values} ->
      learners = Enum.sum(Enum.map(values, & &1.learner_count))
      expected = Enum.sum(Enum.map(values, &(&1.accepted_intents + &1.missed_intents)))
      learned_ticks = Enum.sum(Enum.map(values, & &1.learned_ticks))

      {condition,
       %{
         baby_survival_rate: Enum.sum(Enum.map(values, & &1.baby_survived)) / max(learners, 1),
         participation_survival_rate: Enum.sum(Enum.map(values, & &1.participation_survived)) / max(learners, 1),
         withdrawal_survival_rate: Enum.sum(Enum.map(values, & &1.withdrawal_survived)) / max(learners, 1),
         pair_survival_rate: Enum.count(values, & &1.pair_survived?) / max(length(values), 1),
         mean_self_intake: Enum.sum(Enum.map(values, & &1.self_intake)) / max(learners, 1),
         mean_withdrawal_intake: Enum.sum(Enum.map(values, & &1.withdrawal_intake)) / max(learners, 1),
         mean_contacts: Enum.sum(Enum.map(values, & &1.contacts)) / max(learners, 1),
         mean_feed_sequences: Enum.sum(Enum.map(values, & &1.feed_sequences)) / max(learners, 1),
         mean_phonations: Enum.sum(Enum.map(values, & &1.phonations)) / max(learners, 1),
         mean_peer_responses: Enum.sum(Enum.map(values, & &1.peer_responses)) / max(learners, 1),
         mean_plasticity: Enum.sum(Enum.map(values, & &1.plasticity_total)) / max(learned_ticks, 1),
         mean_surprise: Enum.sum(Enum.map(values, & &1.surprise_total)) / max(learned_ticks, 1),
         mean_episode_count: Enum.sum(Enum.map(values, & &1.episode_count)) / max(learners, 1),
         missed_intent_rate: Enum.sum(Enum.map(values, & &1.missed_intents)) / max(expected, 1)
       }}
    end)
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
