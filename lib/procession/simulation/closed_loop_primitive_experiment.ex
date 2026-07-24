defmodule Procession.Simulation.ClosedLoopPrimitiveExperiment do
  @moduledoc """
  Primitive-body experiment whose `DevelopmentalField` directly drives motor output.

  Sensory and homeostatic activity enters the field. Current field activity and learned
  directed edges excite low-level motor populations through `MentalPlaneMotorReadout`.
  Body consequences return through the same field. No learner action-value table,
  prediction map, semantic action token, or learner-visible episode ledger is used.
  """

  use GenServer

  alias Procession.Simulation.DevelopmentalField
  alias Procession.Simulation.MentalPlaneMotorReadout

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
  @translations Enum.take(@controls, 4)
  @phonations [:phonate_low, :phonate_high]
  @resources %{{0, 0} => :rough_cool, {3, 0} => :sweet_soft, {2, 3} => :sharp_dry}
  @distractors %{{1, 0} => :rough_cool, {0, 2} => :sweet_soft, {3, 2} => :sharp_dry, {1, 3} => :smooth_warm}

  @field_opts [
    micro_nodes: 128,
    input_width: 3,
    consolidation_threshold: 4,
    coherence_threshold: 0.06,
    reuse_threshold: 0.50,
    edge_retention: 0.9995,
    activity_retention: 0.72,
    plasticity_fanout: 6,
    minimum_compression_gain: 2.0,
    propagation_gain: 1.2,
    motor_threshold: 0.12,
    spontaneous_motor_gain: 0.22,
    rest_control: :relax
  ]

  def controls, do: @controls

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 2)
    baby = Keyword.get(opts, :baby_ticks, 100)
    participation = Keyword.get(opts, :participation_ticks, 100)
    withdrawal = Keyword.get(opts, :withdrawal_ticks, 200)
    seed = Keyword.get(opts, :seed, 73)
    timeout = Keyword.get(opts, :intent_timeout_ms, 20)

    rows =
      for condition <- @conditions, pair <- 1..population do
        run_pair(condition, pair, seed, baby, participation, withdrawal, timeout)
      end

    %{
      execution_model: :mental_plane_closed_sensorimotor_loop,
      action_level: :body_control_primitives,
      controller: :developmental_field_motor_populations,
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
      "Closed-loop primitive developmental experiment",
      "execution=#{result.execution_model}",
      "controller=#{result.controller}",
      "population=#{result.population} baby=#{result.baby_ticks} participation=#{result.participation_ticks} withdrawal=#{result.withdrawal_ticks}",
      "mental-plane activity and directed edges directly excite motor populations",
      "no learner action values, prediction maps, episode memory, or semantic action tokens",
      ""
    ]

    lines = Enum.map(@conditions, &report_line(&1, Map.fetch!(result.summary, &1)))
    Enum.join(header ++ lines, "\n")
  end

  defp report_line(condition, s) do
    "#{condition}: baby=#{fmt(s.baby_survival_rate)} participation=#{fmt(s.participation_survival_rate)} " <>
      "withdrawal=#{fmt(s.withdrawal_survival_rate)} pair=#{fmt(s.pair_survival_rate)} " <>
      "self_intake=#{fmt(s.mean_self_intake)} contacts=#{fmt(s.mean_contacts)} " <>
      "feed_sequences=#{fmt(s.mean_feed_sequences)} phonations=#{fmt(s.mean_phonations)} " <>
      "field_driven=#{fmt(s.mean_field_driven_controls)} spontaneous=#{fmt(s.mean_spontaneous_controls)} " <>
      "motor_margin=#{fmt(s.mean_motor_margin)} generated=#{fmt(s.mean_generated_nodes)} " <>
      "missed=#{fmt(s.missed_intent_rate)}"
  end

  defp run_pair(condition, pair, seed, baby, participation, withdrawal, timeout) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)

    try do
      pids = start_learners(supervisor, pair, seed)
      total = baby + participation + withdrawal

      initial = %{
        resources: Map.new(Map.keys(@resources), &{&1, 0.80}),
        sounds: %{a: nil, b: nil},
        accepted: 0,
        missed: 0,
        late: 0,
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
        self_intake: sum(snapshots, :self_intake),
        caregiver_intake: sum(snapshots, :caregiver_intake),
        withdrawal_intake: sum(snapshots, :withdrawal_intake),
        contacts: sum(snapshots, :contacts),
        feed_sequences: sum(snapshots, :feed_sequences),
        phonations: sum(snapshots, :phonations),
        field_driven_controls: sum(snapshots, :field_driven_controls),
        spontaneous_controls: sum(snapshots, :spontaneous_controls),
        motor_margin_total: sum(snapshots, :motor_margin_total),
        generated_nodes: sum(snapshots, :generated_nodes),
        ticks: sum(snapshots, :tick)
      }
    after
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor)
    end
  end

  defp start_learners(supervisor, pair, seed) do
    Map.new([:a, :b], fn id ->
      learner_seed = seed + pair * 10_007 + if(id == :a, do: 101, else: 503)
      opts = Keyword.put(@field_opts, :encoding_salt, {:closed_loop, pair, id, seed})
      spec = %{
        id: {__MODULE__, make_ref()},
        start: {__MODULE__, :start_link, [[id: id, seed: learner_seed, field_opts: opts]]},
        restart: :temporary
      }
      {:ok, pid} = DynamicSupervisor.start_child(supervisor, spec)
      {id, pid}
    end)
  end

  defp tick_world(pids, condition, phase, tick, world, timeout) do
    resources = regenerate(world.resources)
    states = Map.new(pids, fn {id, pid} -> {id, snapshot(pid)} end)

    Enum.each([:a, :b], fn id ->
      sensory = sensory_frame(states[id], states[other(id)], resources, world.sounds[id], condition, phase)
      GenServer.cast(pids[id], {:sense_and_act, self(), tick, sensory})
    end)

    deadline = System.monotonic_time(:millisecond) + timeout
    {intents, late} = collect_until(tick, MapSet.new([:a, :b]), deadline, %{}, 0)
    controls = Map.new([:a, :b], fn id -> {id, get_in(intents, [id, :control]) || :relax} end)
    proposals = Map.new([:a, :b], &proposal(&1, states[&1], controls[&1], resources, phase))
    allocations = allocate(resources, proposals)
    resources = consume(resources, proposals, allocations)

    {resources, outcomes} =
      Enum.reduce([:a, :b], {resources, %{}}, fn id, {amounts, acc} ->
        p = proposals[id]
        self_intake = allocations[id]
        {amounts, caregiver_intake} = caregiver(condition, phase, p.position, amounts, 1.0 - p.depleted, self_intake)

        outcome = %{
          position: p.position,
          limb_extension: p.limb_extension,
          fatigue: p.fatigue,
          contact?: p.contact?,
          vitality: min(1.0, p.depleted + self_intake + caregiver_intake),
          self_intake: self_intake,
          caregiver_intake: caregiver_intake
        }

        {amounts, Map.put(acc, id, outcome)}
      end)

    Enum.each([:a, :b], fn id ->
      :ok = GenServer.call(pids[id], {:body_feedback, controls[id], outcomes[id], phase}, :infinity)
    end)

    sounds =
      Map.new([:a, :b], fn id ->
        peer_control = controls[other(id)]
        sound = if audible?(condition) and peer_control in @phonations, do: raw_sound(peer_control), else: nil
        {id, sound}
      end)

    accepted = map_size(intents)
    %{world | resources: resources, sounds: sounds, accepted: world.accepted + accepted, missed: world.missed + 2 - accepted, late: world.late + late}
  end

  defp proposal(id, state, control, resources, phase) do
    depleted = max(0.0, state.vitality - 0.014)
    body = apply_control(state, control, phase)
    amount = Map.get(resources, body.position, 0.0)
    contact? = body.limb_extension >= 0.60 and amount > 0.01
    desired = if control == :contract_limb and state.contact? and phase != :baby, do: min(amount, min(0.20, (1.0 - depleted) * 0.30)), else: 0.0
    {id, Map.merge(body, %{depleted: depleted, contact?: contact?, desired: desired})}
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
       self_intake: 0.0,
       caregiver_intake: 0.0,
       withdrawal_intake: 0.0,
       contacts: 0,
       feed_sequences: 0,
       phonations: 0,
       field_driven_controls: 0,
       spontaneous_controls: 0,
       motor_margin_total: 0.0,
       tick: 0
     }}
  end

  @impl true
  def handle_cast({:sense_and_act, owner, tick, sensory}, state) do
    field = DevelopmentalField.step(state.field, {:features, sensory}, Keyword.put(state.field_opts, :plasticity_budget, 0.025))
    {control, combined} = MentalPlaneMotorReadout.select(field, @controls, state.seed, tick, state.field_opts)
    field_only = MentalPlaneMotorReadout.drives(field, @controls, state.field_opts)
    field_winner = field_only |> Enum.max_by(fn {candidate, score} -> {score, candidate} end) |> elem(0)
    margin = motor_margin(combined)
    send(owner, {:closed_loop_intent, tick, state.id, control})

    {:noreply,
     state
     |> Map.put(:field, field)
     |> Map.put(:pending_sensory, sensory)
     |> Map.put(:pending_field_driven?, control == field_winner)
     |> Map.put(:pending_motor_margin, margin)}
  end

  @impl true
  def handle_call({:body_feedback, control, outcome, phase}, _from, state) do
    sensory = Map.get(state, :pending_sensory, [])
    delta = outcome.vitality - state.vitality
    salience = clamp(0.08 + max(delta, 0.0) * 3.0 + max(-delta, 0.0) * 0.8 + if(outcome.contact?, do: 0.20, else: 0.0), 0.08, 1.0)

    feedback =
      {:features,
       sensory ++
         [
           {:motor_channel, control},
           {:proprioception_after, bucket(outcome.limb_extension)},
           {:tactile_after, outcome.contact?},
           {:intake_after, bucket(outcome.self_intake + outcome.caregiver_intake)},
           {:homeostatic_change, signed_bucket(delta)}
         ]}

    field = DevelopmentalField.step(state.field, feedback, Keyword.put(state.field_opts, :plasticity_budget, 0.08 * salience))
    field_driven? = Map.get(state, :pending_field_driven?, false)

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
        last_outcome: {bucket(outcome.limb_extension), outcome.contact?, bucket(outcome.self_intake + outcome.caregiver_intake)},
        self_intake: state.self_intake + outcome.self_intake,
        caregiver_intake: state.caregiver_intake + outcome.caregiver_intake,
        withdrawal_intake: state.withdrawal_intake + if(phase == :withdrawal, do: outcome.self_intake, else: 0.0),
        contacts: state.contacts + if(outcome.contact?, do: 1, else: 0),
        feed_sequences: state.feed_sequences + if(control == :contract_limb and outcome.self_intake > 0.0, do: 1, else: 0),
        phonations: state.phonations + if(control in @phonations, do: 1, else: 0),
        field_driven_controls: state.field_driven_controls + if(field_driven?, do: 1, else: 0),
        spontaneous_controls: state.spontaneous_controls + if(field_driven?, do: 0, else: 1),
        motor_margin_total: state.motor_margin_total + Map.get(state, :pending_motor_margin, 0.0),
        tick: state.tick + 1
    }

    {:reply, :ok, Map.drop(next, [:pending_sensory, :pending_field_driven?, :pending_motor_margin])}
  end

  def handle_call(:snapshot, _from, state) do
    public = Map.drop(state, [:field, :field_opts, :pending_sensory, :pending_field_driven?, :pending_motor_margin])
    {:reply, Map.put(public, :generated_nodes, MapSet.size(state.field.generated)), state}
  end

  defp sensory_frame(state, peer, resources, peer_sound, condition, phase) do
    base = [
      {:body_vitality, bucket(state.vitality)},
      {:body_hunger, bucket(1.0 - state.vitality)},
      {:body_fatigue, bucket(state.fatigue)},
      {:proprioception_extension, bucket(state.limb_extension)},
      {:tactile_contact, state.contact?},
      {:local_signature, sensory_signature(state.position)},
      {:local_amount, bucket(Map.get(resources, state.position, 0.0))},
      {:last_motor_feedback, state.last_control},
      {:last_outcome, state.last_outcome},
      {:teacher_sound, teacher_sound(condition, phase, state, resources)}
    ]

    base = if audible?(condition), do: [{:ambient_sound, peer_sound} | base], else: base

    if visible?(condition) do
      {dx, dy} = relative(state.position, peer.position)
      [{:moving_form_dx, signed_bucket(dx)}, {:moving_form_dy, signed_bucket(dy)}, {:moving_form_motor, peer.last_control}, {:moving_form_contact, peer.contact?} | base]
    else
      base
    end
  end

  defp apply_control(state, control, :baby) when control in @translations,
    do: %{position: state.position, limb_extension: state.limb_extension, fatigue: state.fatigue}

  defp apply_control(state, :translate_x_positive, _), do: move(state, {1, 0})
  defp apply_control(state, :translate_x_negative, _), do: move(state, {-1, 0})
  defp apply_control(state, :translate_y_positive, _), do: move(state, {0, 1})
  defp apply_control(state, :translate_y_negative, _), do: move(state, {0, -1})
  defp apply_control(state, :extend_limb, _), do: %{position: state.position, limb_extension: min(1.0, state.limb_extension + 0.25), fatigue: min(1.0, state.fatigue + 0.02)}
  defp apply_control(state, :contract_limb, _), do: %{position: state.position, limb_extension: max(0.0, state.limb_extension - 0.30), fatigue: min(1.0, state.fatigue + 0.015)}
  defp apply_control(state, control, _) when control in @phonations, do: %{position: state.position, limb_extension: state.limb_extension, fatigue: min(1.0, state.fatigue + 0.008)}
  defp apply_control(state, :relax, _), do: %{position: state.position, limb_extension: max(0.0, state.limb_extension - 0.05), fatigue: max(0.0, state.fatigue - 0.07)}

  defp move(state, {dx, dy}) do
    {x, y} = state.position
    %{position: {clamp_int(x + dx, 0, 3), clamp_int(y + dy, 0, 3)}, limb_extension: state.limb_extension, fatigue: min(1.0, state.fatigue + 0.045)}
  end

  defp teacher_sound(condition, :withdrawal, _state, _resources) when condition in [:teacher_pair_invisible, :teacher_pair_visible, :teacher_pair_audible], do: nil
  defp teacher_sound(condition, phase, state, resources) when condition in [:teacher_pair_invisible, :teacher_pair_visible, :teacher_pair_audible] do
    cond do
      phase == :baby and 1.0 - state.vitality > 0.38 -> {:pulse, :low, :short}
      phase == :baby -> {:pulse, :low, :soft}
      1.0 - state.vitality <= 0.58 -> {:pulse, :low, :soft}
      Map.get(resources, state.position, 0.0) > 0.01 -> {:pulse, :high, :short}
      true -> {:pulse, :high, :long}
    end
  end
  defp teacher_sound(_, _, _, _), do: nil

  defp caregiver(condition, :withdrawal, _position, resources, _hunger, _self) when condition in [:teacher_pair_invisible, :teacher_pair_visible, :teacher_pair_audible], do: {resources, 0.0}
  defp caregiver(condition, :baby, _position, resources, hunger, _self) when condition in [:teacher_pair_invisible, :teacher_pair_visible, :teacher_pair_audible], do: {resources, if(hunger > 0.38, do: min(0.20, hunger * 0.30), else: 0.0)}
  defp caregiver(condition, :participation, position, resources, hunger, self_intake) when condition in [:teacher_pair_invisible, :teacher_pair_visible, :teacher_pair_audible] do
    next = if hunger > 0.58 and self_intake <= 0.0, do: Map.put(resources, position, max(Map.get(resources, position, 0.0), 0.20)), else: resources
    {next, 0.0}
  end
  defp caregiver(_, _, _, resources, _, _), do: {resources, 0.0}

  defp allocate(resources, proposals) do
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

  defp consume(resources, proposals, allocations) do
    Enum.reduce([:a, :b], resources, fn id, amounts ->
      amount = allocations[id]
      if amount > 0.0, do: Map.update!(amounts, proposals[id].position, &max(0.0, &1 - amount)), else: amounts
    end)
  end

  defp collect_until(tick, pending, deadline, intents, late) do
    if MapSet.size(pending) == 0 do
      {intents, late}
    else
      remaining = max(deadline - System.monotonic_time(:millisecond), 0)

      receive do
        {:closed_loop_intent, ^tick, id, control} ->
          collect_until(tick, MapSet.delete(pending, id), deadline, Map.put_new(intents, id, %{control: control}), late)

        {:closed_loop_intent, _other_tick, _id, _control} ->
          collect_until(tick, pending, deadline, intents, late + 1)
      after
        remaining -> {intents, late}
      end
    end
  end

  defp summarize(rows) do
    rows
    |> Enum.group_by(& &1.condition)
    |> Map.new(fn {condition, group} ->
      learners = Enum.sum(Enum.map(group, & &1.learner_count))
      ticks = max(Enum.sum(Enum.map(group, & &1.ticks)), 1)
      intents = max(Enum.sum(Enum.map(group, &(&1.accepted_intents + &1.missed_intents))), 1)

      {condition,
       %{
         baby_survival_rate: Enum.sum(Enum.map(group, & &1.baby_survived)) / learners,
         participation_survival_rate: Enum.sum(Enum.map(group, & &1.participation_survived)) / learners,
         withdrawal_survival_rate: Enum.sum(Enum.map(group, & &1.withdrawal_survived)) / learners,
         pair_survival_rate: Enum.count(group, & &1.pair_survived?) / length(group),
         mean_self_intake: Enum.sum(Enum.map(group, & &1.self_intake)) / learners,
         mean_contacts: Enum.sum(Enum.map(group, & &1.contacts)) / learners,
         mean_feed_sequences: Enum.sum(Enum.map(group, & &1.feed_sequences)) / learners,
         mean_phonations: Enum.sum(Enum.map(group, & &1.phonations)) / learners,
         mean_field_driven_controls: Enum.sum(Enum.map(group, & &1.field_driven_controls)) / learners,
         mean_spontaneous_controls: Enum.sum(Enum.map(group, & &1.spontaneous_controls)) / learners,
         mean_motor_margin: Enum.sum(Enum.map(group, & &1.motor_margin_total)) / ticks,
         mean_generated_nodes: Enum.sum(Enum.map(group, & &1.generated_nodes)) / learners,
         missed_intent_rate: Enum.sum(Enum.map(group, & &1.missed_intents)) / intents
       }}
    end)
  end

  defp motor_margin(scores) do
    sorted = scores |> Map.values() |> Enum.sort(:desc)
    Enum.at(sorted, 0, 0.0) - Enum.at(sorted, 1, 0.0)
  end

  defp regenerate(resources), do: Map.new(resources, fn {position, amount} -> {position, min(0.80, amount + 0.006)} end)
  defp sensory_signature(position), do: Map.get(@resources, position) || Map.get(@distractors, position) || :empty
  defp raw_sound(:phonate_low), do: {:wave, :low, :brief}
  defp raw_sound(:phonate_high), do: {:wave, :high, :brief}
  defp visible?(:teacher_pair_invisible), do: false
  defp visible?(_), do: true
  defp audible?(condition), do: condition in [:teacher_pair_audible, :orphan_pair_audible]
  defp other(:a), do: :b
  defp other(:b), do: :a
  defp relative({x1, y1}, {x2, y2}), do: {x2 - x1, y2 - y1}
  defp phase(tick, baby, _participation) when tick <= baby, do: :baby
  defp phase(tick, baby, participation) when tick <= baby + participation, do: :participation
  defp phase(_, _, _), do: :withdrawal
  defp alive_count(pids), do: Enum.count(pids, fn {_id, pid} -> snapshot(pid).alive? end)
  defp sum(snapshots, key), do: Enum.sum(Enum.map(snapshots, fn {_id, state} -> Map.fetch!(state, key) end))
  defp bucket(value) when value <= 0.0, do: :none
  defp bucket(value) when value < 0.25, do: :low
  defp bucket(value) when value < 0.60, do: :medium
  defp bucket(value) when value < 0.85, do: :high
  defp bucket(_), do: :very_high
  defp signed_bucket(value) when value <= -2, do: :far_negative
  defp signed_bucket(value) when value < 0, do: :negative
  defp signed_bucket(0), do: :zero
  defp signed_bucket(value) when value < 2, do: :positive
  defp signed_bucket(_), do: :far_positive
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
  defp clamp_int(value, low, high), do: value |> max(low) |> min(high)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
