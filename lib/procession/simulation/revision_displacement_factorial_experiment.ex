defmodule Procession.Simulation.RevisionDisplacementFactorialExperiment do
  @moduledoc """
  Iteration 002 factorial over the existing association-reversal substrate.

  C0 preserves the current local-adaptive update balance. V1 changes only the
  magnitude of the existing locally attributed contradiction disturbance. V2
  adds finite support-conserving competition after ordinary successful local
  reinforcement. V3 combines those two bounded changes.

  World phase labels, correctness, support accounting, and restoration metrics
  are observer-only and never enter action selection.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.LocalTrace

  @experiment_id "council_iteration_002_revision_displacement_factorial"
  @schema_version 1
  @actions [:left, :right, :remain]
  @variant_specs [
    %{id: "C0", disturbance_factor: 1.0, competition?: false},
    %{id: "V1", disturbance_factor: 2.0, competition?: false},
    %{id: "V2", disturbance_factor: 1.0, competition?: true},
    %{id: "V3", disturbance_factor: 2.0, competition?: true}
  ]
  @defaults [
    samples: 100,
    first_seed: 1,
    pre_ticks: 90,
    post_ticks: 180,
    restoration_ticks: 30,
    window_ticks: 30,
    recovery_window_ticks: 5,
    competition_fraction: 0.25
  ]

  defmodule State do
    @moduledoc false
    defstruct variant_id: "C0",
              disturbance_factor: 1.0,
              competition?: false,
              seed: 1,
              tick: 0,
              position: 5,
              field: nil,
              traces: %{},
              pending: [],
              correct_attributions: 0,
              mistaken_attributions: 0,
              eligible_negative_effects: 0,
              disturbance_events: [],
              competition_events: [],
              successful_deposit: 0.0,
              displaced_support: 0.0,
              history: [],
              snapshots: %{}
  end

  def experiment_id, do: @experiment_id
  def schema_version, do: @schema_version
  def defaults, do: @defaults
  def variant_specs, do: @variant_specs

  def validate_options(opts) do
    normalized = Keyword.merge(@defaults, opts)

    with :ok <- validate_positive_integers(normalized, [:samples, :first_seed, :pre_ticks, :post_ticks,
             :window_ticks, :recovery_window_ticks]),
         :ok <- validate_nonnegative_integer(normalized, :restoration_ticks),
         :ok <- validate_fraction(normalized, :competition_fraction),
         :ok <- validate_window(normalized) do
      {:ok, normalized}
    end
  end

  def run(opts \\ []) do
    {:ok, options} = validate_options(opts)
    seeds = Enum.to_list(options[:first_seed]..(options[:first_seed] + options[:samples] - 1))

    rows =
      for spec <- @variant_specs, seed <- seeds do
        run_variant(spec, seed, options)
      end

    %{options: options, rows: rows, summary: summarize(rows, options)}
  end

  def run_variant(spec, seed, options) do
    state = run_state(spec, seed, options)
    history = state.history |> Enum.reverse() |> Enum.sort_by(& &1.tick)
    pre = Enum.filter(history, &(&1.phase == :pre))
    post = Enum.filter(history, &(&1.phase == :post))
    restoration = Enum.filter(history, &(&1.phase == :restoration))
    behavioral_delay = behavioral_delay_for_history(post, options[:window_ticks], options[:post_ticks])
    resistance_delay = resistance_delay(state.snapshots, options[:post_ticks])
    closed_events = close_remaining_events(state.disturbance_events, state.field)
    removed = Enum.sum(Enum.map(closed_events, & &1.actual_removed))
    recovered = Enum.sum(Enum.map(closed_events, & &1.same_path_reinforcement))
    recovery_ratio = if removed <= 1.0e-12, do: 0.0, else: recovered / removed

    %{
      schema_version: @schema_version,
      experiment_id: @experiment_id,
      variant_id: spec.id,
      seed: seed,
      disturbance_factor: spec.disturbance_factor,
      competition_enabled: spec.competition?,
      pre_reversal_ticks: options[:pre_ticks],
      post_reversal_ticks: options[:post_ticks],
      restoration_ticks: options[:restoration_ticks],
      behavioral_corrected: behavioral_delay <= options[:post_ticks],
      behavioral_correction_delay: behavioral_delay,
      resistance_corrected: resistance_delay <= options[:post_ticks],
      resistance_correction_delay: resistance_delay,
      normalized_obsolete_action_rate: action_count(post, :left) / max(length(post), 1),
      post_expression_rate: expression_rate(post),
      post_intake: Enum.sum(Enum.map(post, & &1.intake_after)),
      restoration_expression_rate: expression_rate(restoration),
      restoration_original_action_rate: action_count(restoration, :left) / max(length(restoration), 1),
      eligible_negative_effects: state.eligible_negative_effects,
      disturbance_event_count: length(closed_events),
      total_support_removed: removed,
      five_tick_same_path_reinforcement: recovered,
      five_tick_recovery_ratio: recovery_ratio,
      net_support_change_after_recovery:
        Enum.sum(Enum.map(closed_events, fn event -> event.residue_after_recovery - event.residue_before end)),
      successful_competing_deposit: state.successful_deposit,
      total_displaced_support: state.displaced_support,
      competition_event_count: length(state.competition_events),
      support_snapshots: state.snapshots,
      pre_action_counts: action_counts(pre),
      post_action_counts: action_counts(post),
      restoration_action_counts: action_counts(restoration),
      attribution_diagnostics: %{
        correct: state.correct_attributions,
        mistaken: state.mistaken_attributions
      },
      metric_agreement: agreement(behavioral_delay <= options[:post_ticks], resistance_delay <= options[:post_ticks])
    }
  end

  def run_state(spec, seed, options) do
    total_ticks = options[:pre_ticks] + options[:post_ticks] + options[:restoration_ticks]
    initial = %State{
      variant_id: spec.id,
      disturbance_factor: spec.disturbance_factor,
      competition?: spec.competition?,
      seed: seed,
      field: new_field(),
      traces: LocalTrace.new()
    }

    Enum.reduce(1..total_ticks, initial, fn tick, state -> advance(state, tick, options) end)
  end

  def summarize(rows, options) do
    grouped = Enum.group_by(rows, & &1.variant_id)
    variants = Map.new(@variant_specs, fn %{id: id} -> {id, variant_summary(Map.fetch!(grouped, id))} end)

    paired = Map.new(["V1", "V2", "V3"], fn id ->
      {"C0_to_#{id}", paired_delta(Map.fetch!(grouped, "C0"), Map.fetch!(grouped, id))}
    end)

    %{samples: options[:samples], variants: variants, paired_deltas: paired,
      criteria: criteria(variants, paired), no_architectural_promotion: true}
  end

  def behavioral_delay_for_history(post_history, window_ticks, post_ticks) do
    case post_history
         |> Enum.chunk_every(window_ticks, 1, :discard)
         |> Enum.find_index(&(behavioral_correct?(action_counts(&1)))) do
      nil -> post_ticks + 1
      index -> index + window_ticks
    end
  end

  def behavioral_correct?(counts) do
    total = counts.left + counts.right + counts.remain
    counts.right > counts.left and counts.left / max(total, 1) <= 0.25
  end

  defp advance(state, tick, options) do
    phase = phase(tick, options)
    source = source_for_phase(phase, options)
    before_intake = intake(state.position, source, options)
    {action, activation} = choose_action(state, tick)
    next_position = move(state.position, action, options)
    after_intake = intake(next_position, source, options)
    actual_delta = after_intake - before_intake
    experienced_delta = actual_delta + coincidence(state.seed, tick, options)

    traces = LocalTrace.decay(state.traces, factor: Keyword.get(options, :trace_decay, 0.72))
    action_key = {:action, tick, action}
    displacement_key = {:displacement, tick, sign(next_position - state.position)}
    traces = LocalTrace.activate(traces, action_key, 1.0)
    traces = if next_position == state.position, do: traces,
      else: LocalTrace.activate(traces, displacement_key, 1.0)

    effect = %{due: tick + Keyword.get(options, :effect_delay, 2), action: action,
      activation: activation, actual_delta: actual_delta, experienced_delta: experienced_delta,
      action_key: action_key, displacement_key: displacement_key}
    pending = [effect | state.pending]
    {due, pending} = Enum.split_with(pending, &(&1.due <= tick))

    state = %{state | traces: traces, pending: pending}
    state = Enum.reduce(due, state, &apply_effect(&1, &2, tick, options))
    events = close_due_events(state.disturbance_events, state.field, tick)
    state = %{state | disturbance_events: events}

    history_entry = %{tick: tick, phase: phase, source: source, action: action,
      actual_delta: actual_delta, experienced_delta: experienced_delta,
      intake_before: before_intake, intake_after: after_intake}

    state = %{state | tick: tick, position: next_position,
      history: [history_entry | state.history]}
    snapshot_if_boundary(state, tick, options)
  end

  defp apply_effect(effect, state, tick, options) do
    scale = attribution_scale(effect, state.traces)

    cond do
      effect.experienced_delta > 1.0e-9 and not is_nil(effect.activation) and scale > 0.0 ->
        reinforce_effect(effect, state, tick, scale, options)

      effect.experienced_delta < -1.0e-9 and scale > 0.0 ->
        disturb_effect(effect, state, tick, scale, options)

      true ->
        state
    end
  end

  defp reinforce_effect(effect, state, tick, scale, options) do
    requested = Keyword.get(options, :learning_deposit, 0.11) * scale
    field = reinforce(state.field, effect.action, effect.activation, scale, options)
    {field, displaced, competition_event} = maybe_compete(field, effect, requested, state, tick, options)
    events = credit_reinforcement(state.disturbance_events, effect.action, tick, requested)

    {correct, mistaken} = if effect.actual_delta > 1.0e-9, do: {1, 0}, else: {0, 1}

    %{state | field: field, disturbance_events: events,
      correct_attributions: state.correct_attributions + correct,
      mistaken_attributions: state.mistaken_attributions + mistaken,
      successful_deposit: state.successful_deposit + requested,
      displaced_support: state.displaced_support + displaced,
      competition_events: maybe_prepend(competition_event, state.competition_events)}
  end

  defp disturb_effect(effect, state, tick, scale, options) do
    before = residue(state.field, effect.action)
    requested = Keyword.get(options, :contradiction_magnitude, 0.16) * scale * state.disturbance_factor
    field = CognitiveField.disturb_terminal(state.field, [:strain, effect.action],
      magnitude: requested, fraction: 1.0)
    after_value = residue(field, effect.action)
    event = %{tick: tick, action: effect.action, attribution_scale: scale,
      requested_removal: requested, actual_removed: max(0.0, before - after_value),
      residue_before: before, residue_after: after_value,
      recovery_end_tick: tick + options[:recovery_window_ticks],
      same_path_reinforcement: 0.0, residue_after_recovery: after_value, closed?: false}

    %{state | field: field,
      eligible_negative_effects: state.eligible_negative_effects + 1,
      disturbance_events: [event | state.disturbance_events]}
  end

  defp maybe_compete(field, _effect, _requested, %State{competition?: false}, _tick, _options),
    do: {field, 0.0, nil}

  defp maybe_compete(field, effect, requested, _state, tick, options) do
    active =
      @actions
      |> Enum.reject(&(&1 == effect.action))
      |> Enum.filter(&(Map.get(effect.activation.exit_activation, &1, 0.0) > 0.0))

    budget = requested * options[:competition_fraction]
    available = Enum.sum(Enum.map(active, &residue(field, &1)))
    removed_total = min(budget, available)

    {field, removals} =
      Enum.reduce(active, {field, %{}}, fn action, {acc, removal_map} ->
        share = if available <= 1.0e-12, do: 0.0,
          else: removed_total * residue(field, action) / available
        {remove_residue(acc, action, share), Map.put(removal_map, action, share)}
      end)

    event = %{tick: tick, reinforced_action: effect.action, successful_deposit: requested,
      active_competitors: active, removals: removals, total_displaced: removed_total,
      conservation_ok: removed_total <= budget + 1.0e-12}
    {field, removed_total, event}
  end

  defp credit_reinforcement(events, action, tick, amount) do
    Enum.map(events, fn event ->
      if not event.closed? and event.action == action and tick > event.tick and tick <= event.recovery_end_tick do
        %{event | same_path_reinforcement: event.same_path_reinforcement + amount}
      else
        event
      end
    end)
  end

  defp close_due_events(events, field, tick) do
    Enum.map(events, fn event ->
      if not event.closed? and tick >= event.recovery_end_tick do
        %{event | residue_after_recovery: residue(field, event.action), closed?: true}
      else
        event
      end
    end)
  end

  defp close_remaining_events(events, field) do
    Enum.map(events, fn event ->
      if event.closed?, do: event,
        else: %{event | residue_after_recovery: residue(field, event.action), closed?: true}
    end)
  end

  defp snapshot_if_boundary(state, tick, options) do
    key = cond do
      tick == options[:pre_ticks] -> :pre_end
      tick == options[:pre_ticks] + options[:post_ticks] -> :post_end
      tick == options[:pre_ticks] + options[:post_ticks] + options[:restoration_ticks] -> :restoration_end
      true -> nil
    end

    if key, do: %{state | snapshots: Map.put(state.snapshots, key, support_map(state.field))}, else: state
  end

  defp resistance_delay(snapshots, post_ticks) do
    case snapshots[:post_end] do
      %{left: left, right: right} when right > left -> post_ticks
      _ -> post_ticks + 1
    end
  end

  defp phase(tick, options) do
    cond do
      tick <= options[:pre_ticks] -> :pre
      tick <= options[:pre_ticks] + options[:post_ticks] -> :post
      true -> :restoration
    end
  end

  defp source_for_phase(:pre, _options), do: 0
  defp source_for_phase(:post, options), do: Keyword.get(options, :world_max, 10)
  defp source_for_phase(:restoration, _options), do: 0

  defp attribution_scale(effect, traces) do
    min(LocalTrace.magnitude(traces, effect.action_key),
      LocalTrace.magnitude(traces, effect.displacement_key))
  end

  defp reinforce(field, action, activation, scale, options) do
    FlowLearning.apply(field, Map.take(activation.flows, [{:strain, action}]),
      deposit: Keyword.get(options, :learning_deposit, 0.11) * scale,
      decay_slowing: 0.10, decay_scale: 0.0)
  end

  defp new_field do
    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action)
    end)
  end

  defp choose_action(state, tick) do
    result = PermeableFlow.run(state.field, %{strain: 0.10}, @actions,
      threshold: 0.0001, attenuation: 0.995, permeability_scale: 0.32, max_ticks: 2)
    {weighted_action(result.exit_activation, {state.seed, tick}), result}
  end

  defp residue(field, action) do
    case CognitiveField.transition(field, :strain, action) do
      nil -> 0.0
      transition -> transition.residue
    end
  end

  defp remove_residue(field, action, amount) do
    key = {:strain, action}
    case Map.fetch(field.transitions, key) do
      :error -> field
      {:ok, transition} ->
        updated = %{transition | residue: max(0.0, transition.residue - amount)}
        %{field | transitions: Map.put(field.transitions, key, updated)}
    end
  end

  defp support_map(field), do: Map.new(@actions, &{&1, residue(field, &1)})

  defp intake(position, source, options) do
    peak = Keyword.get(options, :source_intake, 0.22)
    falloff = Keyword.get(options, :intake_falloff, 0.032)
    max(0.0, peak - falloff * abs(position - source))
  end

  defp coincidence(seed, tick, options) do
    rate = Keyword.get(options, :coincidence_rate, 0.18)
    magnitude = Keyword.get(options, :coincidence_magnitude, 0.05)
    if unit({seed, tick, :coincidence}) < rate, do: magnitude, else: 0.0
  end

  defp move(position, :left, _options), do: max(0, position - 1)
  defp move(position, :right, options), do: min(Keyword.get(options, :world_max, 10), position + 1)
  defp move(position, :remain, _options), do: position

  defp weighted_action(weights, seed) do
    entries = Enum.map(@actions, &{&1, max(0.0, Map.get(weights, &1, 0.0))})
    total = Enum.reduce(entries, 0.0, fn {_action, weight}, acc -> acc + weight end)
    if total <= 0.0, do: :remain, else: pick(entries, unit(seed) * total)
  end

  defp pick([{action, _}], _), do: action
  defp pick([{action, weight} | _], threshold) when threshold <= weight, do: action
  defp pick([{_, weight} | rest], threshold), do: pick(rest, threshold - weight)
  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000
  defp sign(value) when value < 0, do: :negative
  defp sign(value) when value > 0, do: :positive
  defp sign(_), do: :none

  defp action_count(history, action), do: Enum.count(history, &(&1.action == action))
  defp action_counts(history), do: %{left: action_count(history, :left),
    right: action_count(history, :right), remain: action_count(history, :remain)}
  defp expression_rate(history), do: (length(history) - action_count(history, :remain)) / max(length(history), 1)
  defp agreement(true, true), do: "agree_corrected"
  defp agreement(false, false), do: "agree_not_corrected"
  defp agreement(_, _), do: "disagree"
  defp maybe_prepend(nil, list), do: list
  defp maybe_prepend(value, list), do: [value | list]

  defp variant_summary(rows) do
    %{
      behavioral_corrected: count_rate(rows, & &1.behavioral_corrected),
      resistance_corrected: count_rate(rows, & &1.resistance_corrected),
      obsolete_action_rate: distribution(Enum.map(rows, & &1.normalized_obsolete_action_rate)),
      expression_rate: distribution(Enum.map(rows, & &1.post_expression_rate)),
      intake: distribution(Enum.map(rows, & &1.post_intake)),
      support_removed: distribution(Enum.map(rows, & &1.total_support_removed)),
      recovery_ratio: distribution(Enum.map(rows, & &1.five_tick_recovery_ratio)),
      displaced_support: distribution(Enum.map(rows, & &1.total_displaced_support)),
      restoration_original_action_rate:
        distribution(Enum.map(rows, & &1.restoration_original_action_rate))
    }
  end

  defp paired_delta(control_rows, treatment_rows) do
    control = Map.new(control_rows, &{&1.seed, &1})
    counts = Enum.frequencies_by(treatment_rows, fn row ->
      before = Map.fetch!(control, row.seed)
      case {before.behavioral_corrected, row.behavioral_corrected} do
        {false, true} -> :improved
        {true, false} -> :worsened
        _ -> :tied
      end
    end)
    %{improved: Map.get(counts, :improved, 0), tied: Map.get(counts, :tied, 0),
      worsened: Map.get(counts, :worsened, 0), denominator: length(treatment_rows)}
  end

  defp criteria(variants, paired) do
    c0 = variants["C0"]
    treatment_ids = ["V1", "V2", "V3"]
    material = Map.new(treatment_ids, fn id ->
      delta = paired["C0_to_#{id}"]
      variant = variants[id]
      safeguards = within_ratio?(variant.expression_rate.median, c0.expression_rate.median, 0.10) and
        within_ratio?(variant.intake.median, c0.intake.median, 0.10) and
        within_ratio?(variant.restoration_original_action_rate.median,
          c0.restoration_original_action_rate.median, 0.20)
      {id, delta.improved - delta.worsened >= 15 and
        c0.obsolete_action_rate.median - variant.obsolete_action_rate.median >= 0.10 and safeguards}
    end)

    success = Enum.any?(material, fn {_id, value} -> value end)
    failure = Enum.all?(treatment_ids, fn id ->
      delta = paired["C0_to_#{id}"]
      variant = variants[id]
      delta.improved < 10 and c0.obsolete_action_rate.median - variant.obsolete_action_rate.median < 0.05 and
        abs(variant.support_removed.median - variant.recovery_ratio.median) < 0.05
    end)

    %{definitions: %{
        success: "a treatment meets paired correction, obsolete-action, activity, intake, restoration, and replay safeguards",
        failure: "all treatments show fewer than 10 paired correction improvements, less than 0.05 obsolete reduction, and no meaningful net support effect",
        magnitude_supported: "V1 materially outperforms C0 while V2 does not",
        competition_supported: "V2 materially outperforms C0 while V1 does not",
        interaction_supported: "V3 materially outperforms both single treatments",
        reinforcement_recovery: "larger removal is followed by at least 0.75 median five-tick recovery without behavioral improvement"
      },
      success: success,
      failure: failure,
      magnitude_supported: material["V1"] and not material["V2"],
      competition_supported: material["V2"] and not material["V1"],
      interaction_supported: material["V3"] and not material["V1"] and not material["V2"],
      reinforcement_recovery: Enum.any?(treatment_ids, fn id ->
        variants[id].support_removed.median > c0.support_removed.median and
          variants[id].recovery_ratio.median >= 0.75 and not material[id]
      end),
      inconclusive: not success and not failure}
  end

  defp count_rate(rows, predicate) do
    count = Enum.count(rows, predicate)
    %{count: count, denominator: length(rows), rate: count / max(length(rows), 1)}
  end

  defp distribution(values) do
    sorted = Enum.sort(values)
    %{median: percentile(sorted, 0.5), iqr: [percentile(sorted, 0.25), percentile(sorted, 0.75)]}
  end

  defp percentile([], _fraction), do: 0.0
  defp percentile(values, fraction), do: Enum.at(values, round((length(values) - 1) * fraction)) * 1.0

  defp within_ratio?(value, baseline, tolerance) when abs(baseline) <= 1.0e-12,
    do: abs(value) <= tolerance
  defp within_ratio?(value, baseline, tolerance), do: abs(value - baseline) / abs(baseline) <= tolerance

  defp validate_positive_integers(options, keys) do
    case Enum.find(keys, fn key -> not (is_integer(options[key]) and options[key] > 0) end) do
      nil -> :ok
      key -> {:error, "#{key} must be a positive integer"}
    end
  end

  defp validate_nonnegative_integer(options, key) do
    if is_integer(options[key]) and options[key] >= 0, do: :ok,
      else: {:error, "#{key} must be a non-negative integer"}
  end

  defp validate_fraction(options, key) do
    if is_number(options[key]) and options[key] >= 0.0 and options[key] <= 1.0, do: :ok,
      else: {:error, "#{key} must be between 0 and 1"}
  end

  defp validate_window(options) do
    if options[:window_ticks] <= options[:post_ticks], do: :ok,
      else: {:error, "window_ticks must not exceed post_ticks"}
  end
end
