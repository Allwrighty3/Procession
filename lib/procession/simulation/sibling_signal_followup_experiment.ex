defmodule Procession.Simulation.SiblingSignalFollowupExperiment do
  @moduledoc """
  Ultra-slow equal-blind sibling diagnostic with world-owned tick deadlines.

  Learners are supervised OTP processes. The world sends tick-tagged perceptions,
  accepts intents until a finite resolution boundary, and advances regardless.
  Missing or late intents become :wait. Developmental support changes bodily
  state only; it never inserts the correct motor action.
  """

  alias Procession.Simulation.SiblingLearnerProcess, as: Learner

  @motor_actions [:left, :right, :collect, :eat, :wait]
  @signals [:signal_a, :signal_b]
  @home 4
  @food 0

  @field_opts [
    micro_nodes: 72,
    input_width: 6,
    activity_retention: 0.82,
    edge_retention: 0.9995,
    output_edge_retention: 0.9995,
    consolidation_threshold: 4,
    minimum_compression_gain: 0.0,
    coherence_threshold: 0.02,
    compression_node_threshold: 0.14,
    compression_coverage_threshold: 0.45,
    plasticity_threshold: 0.14,
    output_source_threshold: 0.14,
    output_learning_scale: 0.01,
    output_plasticity_budget: 0.12,
    output_source_mode: :rising_residual,
    output_specificity_power: 0.5
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 12)
    development_ticks = Keyword.get(opts, :teaching_ticks, 5_000)
    withdrawal_ticks = Keyword.get(opts, :transfer_ticks, 3_000)
    seed = Keyword.get(opts, :seed, 73)
    intent_timeout_ms = Keyword.get(opts, :intent_timeout_ms, 10)
    support_interval = Keyword.get(opts, :support_interval, 40)

    rows =
      for condition <- [:isolated, :visible, :signals], pair <- 1..population do
        run_pair(
          condition,
          pair,
          seed,
          development_ticks,
          withdrawal_ticks,
          intent_timeout_ms,
          support_interval
        )
      end

    %{
      execution_model: :world_owned_deadline_ticks,
      population: population,
      teaching_ticks: development_ticks,
      transfer_ticks: withdrawal_ticks,
      learning_scale: 0.01,
      intent_timeout_ms: intent_timeout_ms,
      support_interval: support_interval,
      rows: rows,
      summary: summarize(rows)
    }
  end

  def report(result) do
    lines =
      Enum.map([:isolated, :visible, :signals], fn condition ->
        s = result.summary[condition]

        "#{condition}: pair_survive=#{fmt(s.pair_survival_rate)} fed=#{fmt(s.learner_meal_rate)} " <>
          "meals=#{fmt(s.mean_meals)} first=#{fmt(s.mean_first_meal_tick)} " <>
          "follow=#{fmt(s.follow_rate)} divergence=#{fmt(s.action_divergence)} " <>
          "missed=#{fmt(s.missed_intent_rate)} late=#{s.late_intents}"
      end)

    signals = result.summary.signals

    Enum.join(
      [
        "Equal-blind OTP sibling diagnostic with world-owned tick deadlines",
        "execution=#{result.execution_model}",
        "population=#{result.population} development=#{result.teaching_ticks} withdrawal=#{result.transfer_ticks} learning=#{result.learning_scale}",
        "intent_timeout_ms=#{result.intent_timeout_ms} support_interval=#{result.support_interval}",
        "caregiver support changes hunger/vitality only; no correct actions are inserted",
        ""
        | lines
      ] ++
        [
          "",
          "signal_attempts=#{signals.signal_attempts} audible=#{fmt(signals.audience_sensitivity)} " <>
            "response=#{fmt(signals.receiver_response_rate)} useful=#{fmt(signals.useful_signal_rate)} " <>
            "conventions=#{fmt(signals.convention_rate)}"
        ],
      "\n"
    )
  end

  defp run_pair(
         condition,
         pair,
         seed,
         development_ticks,
         withdrawal_ticks,
         intent_timeout_ms,
         support_interval
       ) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)

    try do
      {:ok, a} = start_learner(supervisor, :a, pair, seed, 1)
      {:ok, b} = start_learner(supervisor, :b, pair, seed, 3)

      development_metrics =
        Enum.reduce(1..development_ticks, new_metrics(), fn tick, metrics ->
          metrics =
            tick_pair(
              a,
              b,
              condition,
              {:development, tick},
              metrics,
              intent_timeout_ms
            )

          if rem(tick, support_interval) == 0 do
            provide_environmental_support(a)
            provide_environmental_support(b)
            %{metrics | support_events: metrics.support_events + 2}
          else
            metrics
          end
        end)

      :ok = Learner.reset_body(a, 1)
      :ok = Learner.reset_body(b, 3)

      final =
        Enum.reduce(1..withdrawal_ticks, development_metrics, fn tick, metrics ->
          tick_pair(
            a,
            b,
            condition,
            {:withdrawal, tick},
            metrics,
            intent_timeout_ms
          )
        end)

      sa = Learner.snapshot(a)
      sb = Learner.snapshot(b)

      %{
        condition: condition,
        learner_a: sa,
        learner_b: sb,
        pair_survived?: sa.vitality > 0.0 and sb.vitality > 0.0,
        learners_fed: bool(sa.meals > 0) + bool(sb.meals > 0),
        total_meals: sa.meals + sb.meals,
        first_meal_ticks: Enum.reject([sa.first_meal_tick, sb.first_meal_tick], &is_nil/1),
        signals_audible: final.signals_audible,
        signals_inaudible: final.signals_inaudible,
        useful_signals: final.useful_signals,
        receiver_responses: final.receiver_responses,
        follow_events: final.follow_events,
        social_opportunities: final.social_opportunities,
        action_matches: final.action_matches,
        action_comparisons: final.action_comparisons,
        accepted_intents: final.accepted_intents,
        missed_intents: final.missed_intents,
        late_intents: final.late_intents,
        support_events: final.support_events,
        conventions: MapSet.size(final.conventions)
      }
    after
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor)
    end
  end

  defp new_metrics do
    %{
      heard: %{a: nil, b: nil},
      signals_audible: 0,
      signals_inaudible: 0,
      useful_signals: 0,
      receiver_responses: 0,
      follow_events: 0,
      social_opportunities: 0,
      action_matches: 0,
      action_comparisons: 0,
      accepted_intents: 0,
      missed_intents: 0,
      late_intents: 0,
      support_events: 0,
      conventions: MapSet.new()
    }
  end

  defp start_learner(supervisor, id, pair, seed, position) do
    learner_seed = seed + pair * 10_007 + if(id == :a, do: 101, else: 503)
    field_opts = [encoding_salt: {:otp_sibling, pair, id, seed}] ++ @field_opts

    DynamicSupervisor.start_child(supervisor, %{
      id: {Learner, make_ref()},
      start:
        {Learner, :start_link,
         [[id: id, seed: learner_seed, position: position, field_opts: field_opts]]},
      restart: :temporary
    })
  end

  defp tick_pair(a, b, condition, tick, metrics, intent_timeout_ms) do
    sa = Learner.snapshot(a)
    sb = Learner.snapshot(b)
    social? = condition in [:visible, :signals]
    signals? = condition == :signals
    distance_before = abs(sa.position - sb.position)
    audible? = distance_before <= 2

    pa =
      blind_features(
        sa,
        social_features(sa, sb, metrics.heard.a, social?, signals? and audible?)
      )

    pb =
      blind_features(
        sb,
        social_features(sb, sa, metrics.heard.b, social?, signals? and audible?)
      )

    actions = if signals?, do: @motor_actions ++ @signals, else: @motor_actions

    Learner.request_intent(a, self(), tick, pa, actions, 0.20)
    Learner.request_intent(b, self(), tick, pb, actions, 0.20)

    {intents, late_count} = collect_intents(tick, intent_timeout_ms)
    da = Map.get(intents, :a, %{action: :wait, exploratory?: false})
    db = Map.get(intents, :b, %{action: :wait, exploratory?: false})

    oa = resolve_one(sa, da.action)
    ob = resolve_one(sb, db.action)
    :ok = Learner.commit(a, da.action, oa)
    :ok = Learner.commit(b, db.action, ob)

    na = Learner.snapshot(a)
    nb = Learner.snapshot(b)
    distance_after = abs(na.position - nb.position)
    approached_a? = social? and distance_after < distance_before and na.position != sa.position
    approached_b? = social? and distance_after < distance_before and nb.position != sb.position

    signal_a = if da.action in @signals, do: da.action, else: nil
    signal_b = if db.action in @signals, do: db.action, else: nil
    response_a? = signal_b != nil and audible? and approached_a?
    response_b? = signal_a != nil and audible? and approached_b?
    useful_a? = response_b? and sa.position in [@food, @food + 1]
    useful_b? = response_a? and sb.position in [@food, @food + 1]

    conventions =
      metrics.conventions
      |> maybe_convention(metrics.heard.a, da.action, oa.event)
      |> maybe_convention(metrics.heard.b, db.action, ob.event)

    emitted = bool(signal_a != nil) + bool(signal_b != nil)
    audible_count = if audible?, do: emitted, else: 0
    accepted = map_size(intents)
    missed = 2 - accepted

    %{
      metrics
      | heard: %{a: signal_b, b: signal_a},
        signals_audible: metrics.signals_audible + audible_count,
        signals_inaudible: metrics.signals_inaudible + emitted - audible_count,
        useful_signals: metrics.useful_signals + bool(useful_a?) + bool(useful_b?),
        receiver_responses:
          metrics.receiver_responses + bool(response_a?) + bool(response_b?),
        follow_events: metrics.follow_events + bool(approached_a?) + bool(approached_b?),
        social_opportunities:
          metrics.social_opportunities + if(social? and distance_before > 0, do: 2, else: 0),
        action_matches: metrics.action_matches + bool(da.action == db.action),
        action_comparisons: metrics.action_comparisons + 1,
        accepted_intents: metrics.accepted_intents + accepted,
        missed_intents: metrics.missed_intents + missed,
        late_intents: metrics.late_intents + late_count,
        conventions: conventions
    }
  end

  defp collect_intents(tick, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    collect_intents(tick, deadline, %{}, 0)
  end

  defp collect_intents(_tick, _deadline, intents, late) when map_size(intents) == 2,
    do: {intents, late}

  defp collect_intents(tick, deadline, intents, late) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:sibling_intent, ^tick, id, action, exploratory?} ->
        collect_intents(
          tick,
          deadline,
          Map.put_new(intents, id, %{action: action, exploratory?: exploratory?}),
          late
        )

      {:sibling_intent, _other_tick, _id, _action, _exploratory?} ->
        collect_intents(tick, deadline, intents, late + 1)
    after
      remaining -> {intents, late}
    end
  end

  defp provide_environmental_support(pid) do
    state = Learner.snapshot(pid)

    outcome = %{
      position: state.position,
      carrying: state.carrying,
      hunger: max(0.0, state.hunger - 0.35),
      vitality: min(1.0, state.vitality + 0.12),
      coherence: 0.0,
      event: :caregiver_support
    }

    :ok = Learner.commit(pid, :caregiver_support, outcome)
  end

  defp blind_features(state, social) do
    [
      {:at_home_contact, state.position == @home},
      {:at_food_contact, state.position == @food},
      {:carrying, state.carrying},
      {:hunger, band(state.hunger)},
      {:last_action, state.last_action},
      {:last_event, state.last_event}
      | social
    ]
  end

  defp social_features(_self, _other, _heard, false, _hear?), do: []

  defp social_features(self, other, heard, true, hear?) do
    [
      {:sibling_bearing, bearing(self.position, other.position)},
      {:sibling_carrying, other.carrying},
      {:sibling_last_action, other.last_action},
      {:heard_signal, if(hear?, do: heard, else: nil)}
    ]
  end

  defp resolve_one(state, action) do
    {position, carrying, hunger, vitality, coherence, event} =
      case action do
        :left -> move_outcome(state, max(0, state.position - 1))
        :right -> move_outcome(state, min(4, state.position + 1))

        :collect when state.position == @food and not state.carrying ->
          {state.position, true, state.hunger, state.vitality, 1.0, :food_collected}

        :eat when state.position == @home and state.carrying ->
          {state.position, false, max(0.0, state.hunger - 0.75),
           min(1.0, state.vitality + 0.30), 1.0, :food_consumed}

        signal when signal in @signals ->
          {state.position, state.carrying, state.hunger, state.vitality, 0.0, signal}

        :wait ->
          {state.position, state.carrying, state.hunger, state.vitality, -0.02, :waited}

        _ ->
          {state.position, state.carrying, state.hunger, state.vitality, -0.12, :ineffective}
      end

    aged_hunger = min(1.0, hunger + 0.00018)
    aged_vitality = max(0.0, vitality - 0.00004 - aged_hunger * 0.000055)

    %{
      position: position,
      carrying: carrying,
      hunger: aged_hunger,
      vitality: aged_vitality,
      coherence: coherence,
      event: event
    }
  end

  defp move_outcome(state, next) do
    coherence = if next == state.position, do: -0.20, else: 0.35
    {next, state.carrying, state.hunger, state.vitality, coherence, :moved}
  end

  defp summarize(rows) do
    rows
    |> Enum.group_by(& &1.condition)
    |> Map.new(fn {condition, values} ->
      learners = length(values) * 2
      fed = Enum.sum(Enum.map(values, & &1.learners_fed))
      meals = Enum.sum(Enum.map(values, & &1.total_meals))
      firsts = Enum.flat_map(values, & &1.first_meal_ticks)
      audible = Enum.sum(Enum.map(values, & &1.signals_audible))
      inaudible = Enum.sum(Enum.map(values, & &1.signals_inaudible))
      attempts = audible + inaudible
      responses = Enum.sum(Enum.map(values, & &1.receiver_responses))
      useful = Enum.sum(Enum.map(values, & &1.useful_signals))
      follow = Enum.sum(Enum.map(values, & &1.follow_events))
      opportunities = Enum.sum(Enum.map(values, & &1.social_opportunities))
      matches = Enum.sum(Enum.map(values, & &1.action_matches))
      comparisons = Enum.sum(Enum.map(values, & &1.action_comparisons))
      accepted = Enum.sum(Enum.map(values, & &1.accepted_intents))
      missed = Enum.sum(Enum.map(values, & &1.missed_intents))
      late = Enum.sum(Enum.map(values, & &1.late_intents))
      conventions = Enum.sum(Enum.map(values, & &1.conventions))

      {condition,
       %{
         pair_survival_rate: fraction(values, & &1.pair_survived?),
         learner_meal_rate: fed / max(learners, 1),
         mean_meals: meals / max(learners, 1),
         mean_first_meal_tick: mean(firsts),
         follow_rate: ratio(follow, opportunities),
         action_divergence: 1.0 - ratio(matches, comparisons),
         missed_intent_rate: ratio(missed, accepted + missed),
         late_intents: late,
         signal_attempts: attempts,
         audience_sensitivity: ratio(audible, attempts),
         receiver_response_rate: ratio(responses, audible),
         useful_signal_rate: ratio(useful, attempts),
         convention_rate: conventions / max(length(values), 1)
       }}
    end)
  end

  defp maybe_convention(set, nil, _action, _event), do: set

  defp maybe_convention(set, signal, action, event)
       when event in [:food_collected, :food_consumed],
       do: MapSet.put(set, {signal, action, event})

  defp maybe_convention(set, _signal, _action, _event), do: set
  defp bearing(position, target) when position < target, do: :right
  defp bearing(position, target) when position > target, do: :left
  defp bearing(_position, _target), do: :here
  defp band(value) when value < 0.30, do: :low
  defp band(value) when value < 0.65, do: :rising
  defp band(_value), do: :critical
  defp bool(true), do: 1
  defp bool(false), do: 0
  defp fraction([], _fun), do: 0.0
  defp fraction(values, fun), do: Enum.count(values, fun) / length(values)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp ratio(_n, 0), do: 0.0
  defp ratio(n, d), do: n / d
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
