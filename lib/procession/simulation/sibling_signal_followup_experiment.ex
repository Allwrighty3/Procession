defmodule Procession.Simulation.SiblingSignalFollowupExperiment do
  @moduledoc """
  Ultra-slow sibling-development diagnostic using supervised OTP learner processes.

  Both learners have identical blind perception. They differ only in exploration
  stream and developmental history. Their decisions are computed concurrently
  from the same world snapshot, then resolved together by a deterministic tick
  coordinator.
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
    teaching_ticks = Keyword.get(opts, :teaching_ticks, 5_000)
    transfer_ticks = Keyword.get(opts, :transfer_ticks, 3_000)
    seed = Keyword.get(opts, :seed, 73)

    rows =
      for condition <- [:isolated, :visible, :signals], pair <- 1..population do
        run_pair(condition, pair, seed, teaching_ticks, transfer_ticks)
      end

    %{
      execution_model: :supervised_otp_concurrent_decision,
      population: population,
      teaching_ticks: teaching_ticks,
      transfer_ticks: transfer_ticks,
      learning_scale: 0.01,
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
          "follow=#{fmt(s.follow_rate)} action_divergence=#{fmt(s.action_divergence)}"
      end)

    signals = result.summary.signals

    Enum.join([
      "Equal-blind OTP sibling and arbitrary-signal diagnostic",
      "execution=#{result.execution_model}",
      "population=#{result.population} teaching=#{result.teaching_ticks} transfer=#{result.transfer_ticks} learning=#{result.learning_scale}",
      "both learners use identical blind perception and independent exploration streams",
      "" | lines
    ] ++ [
      "",
      "signal_attempts=#{signals.signal_attempts} audible=#{fmt(signals.audience_sensitivity)} " <>
        "response=#{fmt(signals.receiver_response_rate)} useful=#{fmt(signals.useful_signal_rate)} " <>
        "conventions=#{fmt(signals.convention_rate)}"
    ], "\n")
  end

  defp run_pair(condition, pair, seed, teaching_ticks, transfer_ticks) do
    {:ok, supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)

    try do
      {:ok, a} = start_learner(supervisor, :a, pair, seed, 1)
      {:ok, b} = start_learner(supervisor, :b, pair, seed, 3)

      train_pair(a, b, teaching_ticks)

      initial = %{
        heard: %{a: nil, b: nil},
        signals_audible: 0,
        signals_inaudible: 0,
        useful_signals: 0,
        receiver_responses: 0,
        follow_events: 0,
        social_opportunities: 0,
        action_matches: 0,
        action_comparisons: 0,
        conventions: MapSet.new()
      }

      final =
        Enum.reduce(1..transfer_ticks, initial, fn tick, metrics ->
          tick_pair(a, b, condition, tick, metrics)
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
        conventions: MapSet.size(final.conventions)
      }
    after
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor)
    end
  end

  defp start_learner(supervisor, id, pair, seed, position) do
    learner_seed = seed + pair * 10_007 + if(id == :a, do: 101, else: 503)
    field_opts = [encoding_salt: {:otp_sibling, pair, id, seed}] ++ @field_opts

    DynamicSupervisor.start_child(supervisor, %{
      id: {Learner, make_ref()},
      start: {Learner, :start_link, [[id: id, seed: learner_seed, position: position, field_opts: field_opts]]},
      restart: :temporary
    })
  end

  defp train_pair(a, b, ticks) do
    Enum.each(1..ticks, fn _tick ->
      Enum.each([a, b], fn pid ->
        state = Learner.snapshot(pid)
        perception = blind_features(state, [])
        action = desired_action(state)
        outcome = resolve_one(state, action)
        :ok = Learner.train(pid, perception, action, outcome)
      end)
    end)
  end

  defp tick_pair(a, b, condition, tick, metrics) do
    sa = Learner.snapshot(a)
    sb = Learner.snapshot(b)
    social? = condition in [:visible, :signals]
    signals? = condition == :signals
    distance_before = abs(sa.position - sb.position)
    audible? = distance_before <= 2

    pa = blind_features(sa, social_features(sa, sb, metrics.heard.a, social?, signals? and audible?))
    pb = blind_features(sb, social_features(sb, sa, metrics.heard.b, social?, signals? and audible?))
    actions = if signals?, do: @motor_actions ++ @signals, else: @motor_actions

    task_a = Task.async(fn -> Learner.decide(a, pa, actions, tick, 0.20) end)
    task_b = Task.async(fn -> Learner.decide(b, pb, actions, tick, 0.20) end)
    da = Task.await(task_a, :infinity)
    db = Task.await(task_b, :infinity)

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

    %{
      metrics
      | heard: %{a: signal_b, b: signal_a},
        signals_audible: metrics.signals_audible + audible_count,
        signals_inaudible: metrics.signals_inaudible + emitted - audible_count,
        useful_signals: metrics.useful_signals + bool(useful_a?) + bool(useful_b?),
        receiver_responses: metrics.receiver_responses + bool(response_a?) + bool(response_b?),
        follow_events: metrics.follow_events + bool(approached_a?) + bool(approached_b?),
        social_opportunities: metrics.social_opportunities + if(social? and distance_before > 0, do: 2, else: 0),
        action_matches: metrics.action_matches + bool(da.action == db.action),
        action_comparisons: metrics.action_comparisons + 1,
        conventions: conventions
    }
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

  defp desired_action(%{carrying: false, position: @food}), do: :collect
  defp desired_action(%{carrying: true, position: @home}), do: :eat
  defp desired_action(%{carrying: false, position: position}), do: toward(position, @food)
  defp desired_action(%{carrying: true, position: position}), do: toward(position, @home)

  defp resolve_one(state, action) do
    {position, carrying, hunger, vitality, coherence, event} =
      case action do
        :left -> move_outcome(state, max(0, state.position - 1))
        :right -> move_outcome(state, min(4, state.position + 1))
        :collect when state.position == @food and not state.carrying ->
          {state.position, true, state.hunger, state.vitality, 1.0, :food_collected}
        :eat when state.position == @home and state.carrying ->
          {state.position, false, max(0.0, state.hunger - 0.75), min(1.0, state.vitality + 0.30), 1.0, :food_consumed}
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
      conventions = Enum.sum(Enum.map(values, & &1.conventions))

      {condition, %{
        pair_survival_rate: fraction(values, & &1.pair_survived?),
        learner_meal_rate: fed / max(learners, 1),
        mean_meals: meals / max(learners, 1),
        mean_first_meal_tick: mean(firsts),
        follow_rate: ratio(follow, opportunities),
        action_divergence: 1.0 - ratio(matches, comparisons),
        signal_attempts: attempts,
        audience_sensitivity: ratio(audible, attempts),
        receiver_response_rate: ratio(responses, audible),
        useful_signal_rate: ratio(useful, attempts),
        convention_rate: conventions / max(length(values), 1)
      }}
    end)
  end

  defp maybe_convention(set, nil, _action, _event), do: set
  defp maybe_convention(set, signal, action, event) when event in [:food_collected, :food_consumed],
    do: MapSet.put(set, {signal, action, event})
  defp maybe_convention(set, _signal, _action, _event), do: set
  defp toward(position, target) when position < target, do: :right
  defp toward(position, target) when position > target, do: :left
  defp toward(_position, _target), do: :wait
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
