defmodule Procession.Simulation.SiblingSignalFollowupExperiment do
  @moduledoc """
  Follow-up diagnostic that removes direct target-bearing information from the
  second learner after transfer.

  A relationally trained scout can still perceive the current resource bearing.
  The sibling receives only contact, internal, and action/outcome features. In
  social conditions it may also perceive the scout and, in the signal condition,
  one of two arbitrary signal patterns. Signals have no predefined meaning.
  """

  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

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
    output_learning_scale: 0.20,
    output_plasticity_budget: 0.12,
    output_source_mode: :rising_residual,
    output_specificity_power: 0.5
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 16)
    teaching_ticks = Keyword.get(opts, :teaching_ticks, 120)
    transfer_ticks = Keyword.get(opts, :transfer_ticks, 320)
    seed = Keyword.get(opts, :seed, 73)

    rows =
      for condition <- [:isolated, :visible, :signals], pair <- 1..population do
        run_pair(condition, pair, seed, teaching_ticks, transfer_ticks)
      end

    %{
      population: population,
      teaching_ticks: teaching_ticks,
      transfer_ticks: transfer_ticks,
      rows: rows,
      summary: summarize(rows)
    }
  end

  def report(result) do
    lines =
      Enum.map([:isolated, :visible, :signals], fn condition ->
        s = result.summary[condition]

        "#{condition}: sibling_survive=#{fmt(s.sibling_survival_rate)} " <>
          "sibling_meal=#{fmt(s.sibling_meal_rate)} meals=#{fmt(s.mean_sibling_meals)} " <>
          "first_meal=#{fmt(s.mean_first_meal_tick)} scout_meals=#{fmt(s.mean_scout_meals)} " <>
          "follow=#{fmt(s.follow_rate)} contact=#{fmt(s.scout_contact_rate)}"
      end)

    signals = result.summary.signals

    Enum.join([
      "Blinded sibling and arbitrary-signal follow-up",
      "population=#{result.population} teaching=#{result.teaching_ticks} transfer=#{result.transfer_ticks}",
      "follower has no target-bearing feature after transfer",
      "" | lines
    ] ++ [
      "",
      "signal_attempts=#{signals.signal_attempts} useful_signal_rate=#{fmt(signals.useful_signal_rate)} " <>
        "audience_sensitivity=#{fmt(signals.audience_sensitivity)} " <>
        "receiver_response=#{fmt(signals.receiver_response_rate)} conventions=#{fmt(signals.convention_rate)}"
    ], "\n")
  end

  defp run_pair(condition, pair, seed, teaching_ticks, transfer_ticks) do
    scout_opts = opts(seed, {:scout, condition, pair})
    sibling_opts = opts(seed, {:sibling, condition, pair})

    {scout, sibling} =
      Enum.reduce(1..teaching_ticks, {new_learner(scout_opts), new_learner(sibling_opts)}, fn tick, {a, b} ->
        {
          taught_step(a, 0, 4, :relational, scout_opts, tick),
          taught_step(b, 0, 4, :absolute, sibling_opts, tick)
        }
      end)

    initial = %{
      scout: reset_transfer(scout, 4),
      sibling: reset_transfer(sibling, 2),
      heard_signal: nil,
      pending_signal: nil,
      signals_audible: 0,
      signals_inaudible: 0,
      useful_signals: 0,
      receiver_responses: 0,
      follow_events: 0,
      social_opportunities: 0,
      scout_contacts: 0,
      conventions: MapSet.new()
    }

    final =
      Enum.reduce(1..transfer_ticks, initial, fn tick, pair_state ->
        step_pair(pair_state, condition, tick, pair, seed, scout_opts, sibling_opts)
      end)

    %{
      condition: condition,
      scout_survived?: final.scout.vitality > 0.0,
      sibling_survived?: final.sibling.vitality > 0.0,
      scout_meals: final.scout.meals,
      sibling_meals: final.sibling.meals,
      sibling_first_meal_tick: final.sibling.first_meal_tick,
      signals_audible: final.signals_audible,
      signals_inaudible: final.signals_inaudible,
      useful_signals: final.useful_signals,
      receiver_responses: final.receiver_responses,
      follow_events: final.follow_events,
      social_opportunities: final.social_opportunities,
      scout_contacts: final.scout_contacts,
      conventions: MapSet.size(final.conventions)
    }
  end

  defp step_pair(pair_state, condition, tick, pair, seed, scout_opts, sibling_opts) do
    scout = pair_state.scout
    sibling = pair_state.sibling
    social? = condition in [:visible, :signals]
    signals? = condition == :signals
    distance_before = abs(scout.position - sibling.position)
    audible? = distance_before <= 2

    scout_social = if social?, do: sibling_features(scout, sibling, nil), else: []
    heard = if signals? and audible?, do: pair_state.heard_signal, else: nil
    sibling_social = if social?, do: sibling_features(sibling, scout, heard), else: []

    scout_field = Field.sense(scout.field, relational_features(scout, scout_social), scout_opts)
    sibling_field = Field.sense(sibling.field, blind_features(sibling, sibling_social), sibling_opts)

    scout_actions = if signals?, do: @motor_actions ++ @signals, else: @motor_actions
    scout_action = choose_action(scout_field, scout_actions, tick, seed + pair * 311, scout_opts, if(signals?, do: 0.22, else: 0.10))
    sibling_action = choose_action(sibling_field, @motor_actions, tick, seed + pair * 419, sibling_opts, 0.24)

    {next_scout, scout_coherence, scout_event} = apply_action(%{scout | field: scout_field}, scout_action)
    {next_sibling, sibling_coherence, sibling_event} = apply_action(%{sibling | field: sibling_field}, sibling_action)

    distance_after = abs(next_scout.position - next_sibling.position)
    follower_approached? = social? and distance_after < distance_before
    signal = if scout_action in @signals, do: scout_action, else: nil
    response? = signal != nil and audible? and follower_approached?
    useful_signal? = response? and next_scout.position in [@food, @food + 1]

    scout_coherence =
      cond do
        signal == nil -> scout_coherence
        useful_signal? -> 1.0
        response? -> 0.35
        true -> -0.08
      end

    sibling_coherence =
      cond do
        heard != nil and sibling_event in [:food_collected, :food_consumed] -> 1.0
        heard != nil and follower_approached? -> max(sibling_coherence, 0.55)
        true -> sibling_coherence
      end

    next_scout =
      %{next_scout |
        field: Field.record_output(next_scout.field, scout_action, scout_coherence, scout_opts),
        last_event: scout_event
      }
      |> age_body()

    next_sibling =
      %{next_sibling |
        field: Field.record_output(next_sibling.field, sibling_action, sibling_coherence, sibling_opts),
        last_event: sibling_event
      }
      |> age_body()

    convention =
      if heard != nil and sibling_event in [:food_collected, :food_consumed] do
        {heard, sibling_action}
      end

    %{
      pair_state |
      scout: next_scout,
      sibling: next_sibling,
      heard_signal: signal,
      pending_signal: signal,
      signals_audible: pair_state.signals_audible + bool(signal != nil and audible?),
      signals_inaudible: pair_state.signals_inaudible + bool(signal != nil and not audible?),
      useful_signals: pair_state.useful_signals + bool(useful_signal?),
      receiver_responses: pair_state.receiver_responses + bool(response?),
      follow_events: pair_state.follow_events + bool(follower_approached?),
      social_opportunities: pair_state.social_opportunities + bool(social? and distance_before > 0),
      scout_contacts: pair_state.scout_contacts + bool(distance_after == 0),
      conventions: if(convention, do: MapSet.put(pair_state.conventions, convention), else: pair_state.conventions)
    }
  end

  defp taught_step(state, home, food, encoding, field_opts, _tick) do
    features =
      case encoding do
        :relational -> relational_features(state, [], home, food)
        :absolute -> absolute_features(state, home, food)
      end

    field = Field.sense(state.field, features, field_opts)
    action = desired_action(state, home, food)
    {next, coherence, event} = apply_action(%{state | field: field}, action, home, food)

    %{next |
      field: Field.record_output(next.field, action, coherence, field_opts),
      last_event: event
    }
  end

  defp new_learner(field_opts) do
    %{
      field: Field.new(field_opts),
      position: 0,
      carrying: false,
      hunger: 0.25,
      vitality: 1.0,
      meals: 0,
      elapsed: 0,
      first_meal_tick: nil,
      last_action: nil,
      last_event: :none
    }
  end

  defp reset_transfer(state, position) do
    %{state |
      position: position,
      carrying: false,
      hunger: 0.35,
      vitality: 1.0,
      meals: 0,
      elapsed: 0,
      first_meal_tick: nil,
      last_action: nil,
      last_event: :none
    }
  end

  defp relational_features(state, social, home \\ @home, food \\ @food) do
    target = if state.carrying, do: home, else: food

    [
      {:target_bearing, bearing(state.position, target)},
      {:at_target, state.position == target},
      {:carrying, state.carrying},
      {:hunger, band(state.hunger)},
      {:last_action, state.last_action},
      {:last_event, state.last_event}
      | social
    ]
  end

  defp absolute_features(state, home, food) do
    [
      {:position, state.position},
      {:home, home},
      {:food, food},
      {:carrying, state.carrying},
      {:hunger, band(state.hunger)},
      {:last_action, state.last_action},
      {:last_event, state.last_event}
    ]
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

  defp sibling_features(self, other, heard_signal) do
    [
      {:sibling_bearing, bearing(self.position, other.position)},
      {:sibling_carrying, other.carrying},
      {:sibling_last_action, other.last_action},
      {:heard_signal, heard_signal}
    ]
  end

  defp choose_action(field, actions, tick, seed, field_opts, exploration) do
    roll = :erlang.phash2({:explore, seed, tick}, 100_000) / 100_000

    if roll < exploration do
      Enum.at(actions, rem(:erlang.phash2({:action, seed, tick}), length(actions)))
    else
      scores = Field.output_scores(field, actions, field_opts)
      Enum.max_by(actions, fn action -> {Map.get(scores, action, 0.0), action} end)
    end
  end

  defp desired_action(%{carrying: false, position: position}, _home, food) when position == food, do: :collect
  defp desired_action(%{carrying: true, position: position}, home, _food) when position == home, do: :eat
  defp desired_action(%{carrying: false, position: position}, _home, food), do: toward(position, food)
  defp desired_action(%{carrying: true, position: position}, home, _food), do: toward(position, home)

  defp apply_action(state, action, home \\ @home, food \\ @food) do
    elapsed = state.elapsed + 1
    base = %{state | elapsed: elapsed, last_action: action}

    case action do
      :left ->
        next = max(0, state.position - 1)
        { %{base | position: next}, if(next == state.position, do: -0.20, else: 0.35), :moved }

      :right ->
        next = min(4, state.position + 1)
        { %{base | position: next}, if(next == state.position, do: -0.20, else: 0.35), :moved }

      :collect when state.position == food and not state.carrying ->
        { %{base | carrying: true}, 1.0, :food_collected }

      :eat when state.position == home and state.carrying ->
        first_meal = state.first_meal_tick || elapsed

        { %{base |
            carrying: false,
            hunger: max(0.0, state.hunger - 0.75),
            vitality: min(1.0, state.vitality + 0.30),
            meals: state.meals + 1,
            first_meal_tick: first_meal
          }, 1.0, :food_consumed }

      signal when signal in @signals ->
        {base, 0.0, signal}

      :wait ->
        {base, -0.02, :waited}

      _ ->
        {base, -0.12, :ineffective}
    end
  end

  defp age_body(state) do
    hunger = min(1.0, state.hunger + 0.0045)
    vitality = max(0.0, state.vitality - 0.0014 - hunger * 0.0020)
    %{state | hunger: hunger, vitality: vitality}
  end

  defp summarize(rows) do
    rows
    |> Enum.group_by(& &1.condition)
    |> Map.new(fn {condition, values} ->
      audible = Enum.sum(Enum.map(values, & &1.signals_audible))
      inaudible = Enum.sum(Enum.map(values, & &1.signals_inaudible))
      signal_attempts = audible + inaudible
      useful = Enum.sum(Enum.map(values, & &1.useful_signals))
      responses = Enum.sum(Enum.map(values, & &1.receiver_responses))
      follow = Enum.sum(Enum.map(values, & &1.follow_events))
      opportunities = Enum.sum(Enum.map(values, & &1.social_opportunities))
      contacts = Enum.sum(Enum.map(values, & &1.scout_contacts))
      conventions = Enum.sum(Enum.map(values, & &1.conventions))

      {condition, %{
        sibling_survival_rate: fraction(values, & &1.sibling_survived?),
        sibling_meal_rate: fraction(values, &(&1.sibling_meals > 0)),
        mean_sibling_meals: mean(Enum.map(values, &(&1.sibling_meals * 1.0))),
        mean_first_meal_tick: mean_nonzero(Enum.map(values, &((&1.sibling_first_meal_tick || 0) * 1.0))),
        mean_scout_meals: mean(Enum.map(values, &(&1.scout_meals * 1.0))),
        follow_rate: ratio(follow, opportunities),
        scout_contact_rate: ratio(contacts, length(values) * 320),
        signal_attempts: signal_attempts,
        useful_signal_rate: ratio(useful, signal_attempts),
        audience_sensitivity: ratio(audible, signal_attempts),
        receiver_response_rate: ratio(responses, audible),
        convention_rate: conventions / max(length(values), 1)
      }}
    end)
  end

  defp toward(position, target) when position < target, do: :right
  defp toward(position, target) when position > target, do: :left
  defp toward(_position, _target), do: :wait
  defp bearing(position, target) when position < target, do: :right
  defp bearing(position, target) when position > target, do: :left
  defp bearing(_position, _target), do: :here
  defp band(value) when value < 0.30, do: :low
  defp band(value) when value < 0.65, do: :rising
  defp band(_value), do: :critical
  defp opts(seed, salt), do: [encoding_salt: {:sibling_signal_followup, seed, salt}] ++ @field_opts
  defp bool(true), do: 1
  defp bool(false), do: 0
  defp fraction([], _fun), do: 0.0
  defp fraction(values, fun), do: Enum.count(values, fun) / length(values)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp mean_nonzero(values), do: values |> Enum.reject(&(&1 == 0.0)) |> mean()
  defp ratio(_n, 0), do: 0.0
  defp ratio(n, d), do: n / d
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
