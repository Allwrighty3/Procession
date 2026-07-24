defmodule Procession.Simulation.RelationalSocialDevelopmentExperiment do
  @moduledoc """
  Bounded diagnostic for three developmental questions:

  * does sensorimotor memory transfer when home and food reverse positions?
  * does seeing a concurrent learner improve adaptation?
  * can arbitrary signals acquire useful, audience-sensitive use?

  The experiment does not change learner behavior outside this module.
  """

  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @actions [:left, :right, :collect, :eat, :wait]
  @signals [:signal_a, :signal_b]
  @bounds 0..4

  @field_opts [
    micro_nodes: 96,
    input_width: 7,
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
    output_learning_scale: 0.18,
    output_plasticity_budget: 0.12,
    output_source_mode: :rising_residual,
    output_specificity_power: 0.5
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    teaching_ticks = Keyword.get(opts, :teaching_ticks, 320)
    transfer_ticks = Keyword.get(opts, :transfer_ticks, 480)
    seed = Keyword.get(opts, :seed, 41)

    transfer_rows =
      for encoding <- [:absolute, :relational], entity <- 1..population do
        run_transfer(encoding, entity, seed, teaching_ticks, transfer_ticks)
      end

    sibling_rows =
      for condition <- [:isolated, :visible, :signals], pair <- 1..population do
        run_siblings(condition, pair, seed, teaching_ticks, transfer_ticks)
      end

    %{
      population: population,
      teaching_ticks: teaching_ticks,
      transfer_ticks: transfer_ticks,
      transfer: summarize_transfer(transfer_rows),
      siblings: summarize_siblings(sibling_rows),
      transfer_rows: transfer_rows,
      sibling_rows: sibling_rows
    }
  end

  def report(result) do
    absolute = result.transfer.absolute
    relational = result.transfer.relational
    isolated = result.siblings.isolated
    visible = result.siblings.visible
    signals = result.siblings.signals

    Enum.join([
      "Relational transfer and social development diagnostic",
      "population=#{result.population} teaching=#{result.teaching_ticks} transfer=#{result.transfer_ticks}",
      "",
      "MEMORY TRANSFER",
      transfer_line(:absolute, absolute),
      transfer_line(:relational, relational),
      "",
      "CONCURRENT LEARNER",
      sibling_line(:isolated, isolated),
      sibling_line(:visible, visible),
      sibling_line(:signals, signals),
      "",
      "SIGNAL DETAIL",
      "useful_signal_rate=#{fmt(signals.useful_signal_rate)} audience_sensitivity=#{fmt(signals.audience_sensitivity)} " <>
        "receiver_response=#{fmt(signals.receiver_response_rate)} conventions=#{fmt(signals.convention_rate)}"
    ], "\n")
  end

  defp run_transfer(encoding, entity, seed, teaching_ticks, transfer_ticks) do
    opts = field_opts(seed, {:transfer, encoding, entity})
    learner = new_learner(opts)

    trained =
      Enum.reduce(1..teaching_ticks, learner, fn tick, state ->
        features = features(state, 0, 4, encoding, [])
        field = Field.sense(state.field, features, opts)
        action = desired_action(state, 0, 4)
        {next, coherence, event} = apply_action(%{state | field: field}, action, 0, 4)
        %{next | field: Field.record_output(next.field, action, coherence, opts), last_event: event}
      end)

    tested =
      Enum.reduce(1..transfer_ticks, %{trained | position: 4, carrying: false, hunger: 0.35, vitality: 1.0}, fn tick, state ->
        features = features(state, 4, 0, encoding, [])
        field = Field.sense(state.field, features, opts)
        action = choose_action(field, @actions, tick, seed + entity * 101, opts, 0.12)
        {next, coherence, event} = apply_action(%{state | field: field}, action, 4, 0)
        next = %{next | field: Field.record_output(next.field, action, coherence, opts), last_event: event}
        age_body(next)
      end)

    %{
      encoding: encoding,
      survived?: tested.vitality > 0.0,
      meals: tested.meals,
      first_meal_tick: tested.first_meal_tick,
      obsolete_moves: tested.obsolete_moves,
      generated_nodes: MapSet.size(tested.field.sensory.generated)
    }
  end

  defp run_siblings(condition, pair, seed, teaching_ticks, transfer_ticks) do
    scout_opts = field_opts(seed, {:scout, condition, pair})
    sibling_opts = field_opts(seed, {:sibling, condition, pair})
    scout = new_learner(scout_opts)
    sibling = new_learner(sibling_opts)

    {scout, sibling} =
      Enum.reduce(1..teaching_ticks, {scout, sibling}, fn tick, {a, b} ->
        a = taught_step(a, 0, 4, :relational, scout_opts, tick)
        b = taught_step(b, 0, 4, :relational, sibling_opts, tick)
        {a, b}
      end)

    initial = %{
      scout: %{scout | position: 4, carrying: false, hunger: 0.35, vitality: 1.0},
      sibling: %{sibling | position: 4, carrying: false, hunger: 0.35, vitality: 1.0},
      last_signal: nil,
      signaler: nil,
      signals_with_audience: 0,
      signals_without_audience: 0,
      useful_signals: 0,
      receiver_responses: 0,
      conventions: MapSet.new()
    }

    final =
      Enum.reduce(1..transfer_ticks, initial, fn tick, pair_state ->
        social? = condition in [:visible, :signals]
        signal? = condition == :signals
        a = pair_state.scout
        b = pair_state.sibling

        a_social = social_features(a, b, pair_state.last_signal, social?)
        b_social = social_features(b, a, pair_state.last_signal, social?)

        af = Field.sense(a.field, features(a, 4, 0, :relational, a_social), scout_opts)
        bf = Field.sense(b.field, features(b, 4, 0, :relational, b_social), sibling_opts)

        a_actions = if signal?, do: @actions ++ @signals, else: @actions
        b_actions = @actions
        aa = choose_social_action(af, a_actions, a, b, tick, seed + pair * 307, scout_opts, signal?)
        ba = choose_action(bf, b_actions, tick, seed + pair * 401, sibling_opts, 0.16)

        distance_before = abs(a.position - b.position)
        {an, ac, ae} = apply_action(%{a | field: af}, aa, 4, 0)
        {bn, bc, be} = apply_action(%{b | field: bf}, ba, 4, 0)

        emitted = if aa in @signals, do: aa, else: nil
        distance_after = abs(an.position - bn.position)
        receiver_approached? = emitted != nil and distance_after < distance_before
        useful? = emitted != nil and (receiver_approached? or be in [:food_collected, :food_consumed])

        ac = if emitted != nil, do: if(useful?, do: 0.8, else: -0.05), else: ac
        bc = if pair_state.last_signal != nil and be in [:food_collected, :food_consumed], do: 1.0, else: bc

        an = %{an | field: Field.record_output(an.field, aa, ac, scout_opts), last_event: ae} |> age_body()
        bn = %{bn | field: Field.record_output(bn.field, ba, bc, sibling_opts), last_event: be} |> age_body()

        audience? = abs(a.position - b.position) <= 3
        conventions =
          if pair_state.last_signal != nil and be in [:food_collected, :food_consumed] do
            MapSet.put(pair_state.conventions, {pair_state.last_signal, ba})
          else
            pair_state.conventions
          end

        %{
          pair_state |
          scout: an,
          sibling: bn,
          last_signal: emitted,
          signaler: if(emitted, do: :scout, else: nil),
          signals_with_audience: pair_state.signals_with_audience + if(emitted && audience?, do: 1, else: 0),
          signals_without_audience: pair_state.signals_without_audience + if(emitted && !audience?, do: 1, else: 0),
          useful_signals: pair_state.useful_signals + if(useful?, do: 1, else: 0),
          receiver_responses: pair_state.receiver_responses + if(receiver_approached?, do: 1, else: 0),
          conventions: conventions
        }
      end)

    %{
      condition: condition,
      scout_survived?: final.scout.vitality > 0.0,
      sibling_survived?: final.sibling.vitality > 0.0,
      scout_meals: final.scout.meals,
      sibling_meals: final.sibling.meals,
      sibling_first_meal_tick: final.sibling.first_meal_tick,
      signals_with_audience: final.signals_with_audience,
      signals_without_audience: final.signals_without_audience,
      useful_signals: final.useful_signals,
      receiver_responses: final.receiver_responses,
      conventions: MapSet.size(final.conventions)
    }
  end

  defp taught_step(state, home, food, encoding, opts, _tick) do
    field = Field.sense(state.field, features(state, home, food, encoding, []), opts)
    action = desired_action(state, home, food)
    {next, coherence, event} = apply_action(%{state | field: field}, action, home, food)
    %{next | field: Field.record_output(next.field, action, coherence, opts), last_event: event}
  end

  defp new_learner(opts) do
    %{
      field: Field.new(opts),
      position: 0,
      carrying: false,
      hunger: 0.25,
      vitality: 1.0,
      meals: 0,
      first_meal_tick: nil,
      elapsed: 0,
      obsolete_moves: 0,
      last_action: nil,
      last_event: :none
    }
  end

  defp features(state, home, food, :absolute, social) do
    [
      {:position, state.position},
      {:home, home},
      {:food, food},
      {:carrying, state.carrying},
      {:hunger, band(state.hunger)},
      {:last_action, state.last_action},
      {:last_event, state.last_event}
      | social
    ]
  end

  defp features(state, home, food, :relational, social) do
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

  defp social_features(_self, _other, _signal, false), do: []
  defp social_features(self, other, signal, true) do
    [
      {:sibling_bearing, bearing(self.position, other.position)},
      {:sibling_carrying, other.carrying},
      {:sibling_last_action, other.last_action},
      {:heard_signal, signal}
    ]
  end

  defp desired_action(%{carrying: false, position: p}, _home, food) when p == food, do: :collect
  defp desired_action(%{carrying: true, position: p}, home, _food) when p == home, do: :eat
  defp desired_action(%{carrying: false, position: p}, _home, food), do: move_toward(p, food)
  defp desired_action(%{carrying: true, position: p}, home, _food), do: move_toward(p, home)

  defp choose_social_action(field, actions, self, other, tick, seed, opts, true) do
    exploration = if self.position == 0 and abs(self.position - other.position) > 0, do: 0.28, else: 0.14
    choose_action(field, actions, tick, seed, opts, exploration)
  end
  defp choose_social_action(field, actions, _self, _other, tick, seed, opts, false),
    do: choose_action(field, actions, tick, seed, opts, 0.14)

  defp choose_action(field, actions, tick, seed, opts, exploration) do
    scores = Field.output_scores(field, actions, opts)
    actions
    |> Enum.map(fn action ->
      noise = :erlang.phash2({seed, tick, action}, 100_000) / 100_000
      {action, Map.get(scores, action, 0.0) * (1.0 - exploration) + noise * exploration}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp apply_action(state, action, home, food) do
    elapsed = state.elapsed + 1
    base = %{state | elapsed: elapsed, last_action: action}

    case action do
      :left ->
        next = max(Enum.min(@bounds), state.position - 1)
        obsolete = if next == state.position, do: 1, else: 0
        {%{base | position: next, obsolete_moves: state.obsolete_moves + obsolete}, if(next == state.position, do: -0.2, else: 0.35), :moved}
      :right ->
        next = min(Enum.max(@bounds), state.position + 1)
        obsolete = if next == state.position, do: 1, else: 0
        {%{base | position: next, obsolete_moves: state.obsolete_moves + obsolete}, if(next == state.position, do: -0.2, else: 0.35), :moved}
      :collect when state.position == food and not state.carrying ->
        {%{base | carrying: true}, 1.0, :food_collected}
      :eat when state.position == home and state.carrying ->
        first = state.first_meal_tick || elapsed
        {%{base | carrying: false, hunger: max(0.0, state.hunger - 0.75), vitality: min(1.0, state.vitality + 0.28), meals: state.meals + 1, first_meal_tick: first}, 1.0, :food_consumed}
      action when action in @signals -> {base, 0.0, action}
      :wait -> {base, -0.02, :waited}
      _ -> {base, -0.12, :ineffective}
    end
  end

  defp age_body(state) do
    hunger = min(1.0, state.hunger + 0.0032)
    vitality = max(0.0, state.vitality - 0.0010 - hunger * 0.0016)
    %{state | hunger: hunger, vitality: vitality}
  end

  defp summarize_transfer(rows) do
    rows
    |> Enum.group_by(& &1.encoding)
    |> Map.new(fn {encoding, values} ->
      {encoding, %{
        survival_rate: fraction(values, & &1.survived?),
        meal_rate: fraction(values, &(&1.meals > 0)),
        mean_meals: mean(Enum.map(values, &(&1.meals * 1.0))),
        mean_first_meal_tick: mean(Enum.map(values, &((&1.first_meal_tick || 0) * 1.0))),
        mean_obsolete_moves: mean(Enum.map(values, &(&1.obsolete_moves * 1.0))),
        mean_generated_nodes: mean(Enum.map(values, &(&1.generated_nodes * 1.0)))
      }}
    end)
  end

  defp summarize_siblings(rows) do
    rows
    |> Enum.group_by(& &1.condition)
    |> Map.new(fn {condition, values} ->
      audience = Enum.sum(Enum.map(values, & &1.signals_with_audience))
      no_audience = Enum.sum(Enum.map(values, & &1.signals_without_audience))
      useful = Enum.sum(Enum.map(values, & &1.useful_signals))
      responses = Enum.sum(Enum.map(values, & &1.receiver_responses))
      conventions = Enum.sum(Enum.map(values, & &1.conventions))
      total_signals = audience + no_audience

      {condition, %{
        pair_survival_rate: fraction(values, &(&1.scout_survived? and &1.sibling_survived?)),
        sibling_survival_rate: fraction(values, & &1.sibling_survived?),
        sibling_meal_rate: fraction(values, &(&1.sibling_meals > 0)),
        mean_sibling_meals: mean(Enum.map(values, &(&1.sibling_meals * 1.0))),
        mean_first_meal_tick: mean(Enum.map(values, &((&1.sibling_first_meal_tick || 0) * 1.0))),
        useful_signal_rate: ratio(useful, total_signals),
        audience_sensitivity: ratio(audience, total_signals),
        receiver_response_rate: ratio(responses, total_signals),
        convention_rate: conventions / max(length(values), 1)
      }}
    end)
  end

  defp transfer_line(name, s), do:
    "#{name}: survive=#{fmt(s.survival_rate)} meals=#{fmt(s.meal_rate)} mean_meals=#{fmt(s.mean_meals)} " <>
      "first_meal=#{fmt(s.mean_first_meal_tick)} obsolete=#{fmt(s.mean_obsolete_moves)} generated=#{fmt(s.mean_generated_nodes)}"

  defp sibling_line(name, s), do:
    "#{name}: pair_survive=#{fmt(s.pair_survival_rate)} sibling_survive=#{fmt(s.sibling_survival_rate)} " <>
      "sibling_meals=#{fmt(s.sibling_meal_rate)} mean_meals=#{fmt(s.mean_sibling_meals)} first_meal=#{fmt(s.mean_first_meal_tick)}"

  defp move_toward(position, target) when position < target, do: :right
  defp move_toward(position, target) when position > target, do: :left
  defp move_toward(_position, _target), do: :wait
  defp bearing(position, target) when position < target, do: :right
  defp bearing(position, target) when position > target, do: :left
  defp bearing(_position, _target), do: :here
  defp band(value) when value < 0.30, do: :low
  defp band(value) when value < 0.65, do: :rising
  defp band(_value), do: :critical
  defp field_opts(seed, salt), do: [encoding_salt: {:relational_social, seed, salt}] ++ @field_opts
  defp fraction([], _fun), do: 0.0
  defp fraction(values, fun), do: Enum.count(values, fun) / length(values)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp ratio(_n, 0), do: 0.0
  defp ratio(n, d), do: n / d
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
