defmodule Procession.Simulation.SupportActionTranslationExperiment do
  @moduledoc """
  Iteration 003 read-only support-to-action and scenario-adequacy diagnostic.

  Frozen probes reconstruct cognitive fields from real Iteration 002 residue
  snapshots and measure residue, resistance, exit activation, normalized exit
  share, and deterministic sampled-action frequency. Scenario evaluation keeps
  the existing local-adaptive learner unchanged and varies only the world-side
  post-reversal source location.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.{FlowLearning, PermeableFlow}
  alias Procession.Simulation.LocalTrace
  alias Procession.Simulation.RevisionDisplacementFactorialExperiment, as: Revision

  @experiment_id "council_iteration_003_support_action_translation"
  @schema_version 1
  @actions [:left, :right, :remain]
  @boundaries [:pre_end, :post_end, :restoration_end]
  @defaults [
    samples: 100,
    first_seed: 1,
    pre_ticks: 90,
    post_ticks: 180,
    restoration_ticks: 30,
    window_ticks: 30,
    probe_samples: 1000,
    interior_source: 7,
    world_max: 10
  ]

  def experiment_id, do: @experiment_id
  def schema_version, do: @schema_version
  def defaults, do: @defaults

  def validate_options(opts) do
    normalized = Keyword.merge(@defaults, opts)

    with :ok <- positive(normalized, [:samples, :first_seed, :pre_ticks, :post_ticks,
             :window_ticks, :probe_samples, :world_max]),
         :ok <- nonnegative(normalized, :restoration_ticks),
         :ok <- interior(normalized),
         :ok <- window(normalized) do
      {:ok, normalized}
    end
  end

  def run(opts \\ []) do
    {:ok, options} = validate_options(opts)
    revision = Revision.run(revision_options(options))
    transfer_rows = transfer_rows(revision.rows, options)
    scenario_rows = scenario_rows(options)

    %{
      options: options,
      transfer_rows: transfer_rows,
      scenario_rows: scenario_rows,
      summary: summarize(transfer_rows, scenario_rows),
      no_architectural_promotion: true
    }
  end

  def probe_snapshot(snapshot, probe_samples) when is_map(snapshot) do
    field = field_from_snapshot(snapshot)
    result = PermeableFlow.run(field, %{strain: 0.10}, @actions,
      threshold: 0.0001, attenuation: 0.995, permeability_scale: 0.32, max_ticks: 2)

    exits = Map.new(@actions, &{&1, Map.get(result.exit_activation, &1, 0.0)})
    total = Enum.sum(Map.values(exits))
    shares = Map.new(exits, fn {action, value} ->
      {action, if(total <= 1.0e-12, do: 0.0, else: value / total)}
    end)

    counts =
      1..probe_samples
      |> Enum.map(&weighted_action(exits, {:probe, &1}))
      |> Enum.frequencies()

    frequencies = Map.new(@actions, &{&1, Map.get(counts, &1, 0) / probe_samples})

    %{
      support: Map.new(@actions, &{&1, Map.get(snapshot, &1, 0.0)}),
      resistance: Map.new(@actions, &{&1, CognitiveField.resistance(field, :strain, &1)}),
      exit_activation: exits,
      exit_share: shares,
      sampled_frequency: frequencies,
      support_exit_rank_agreement: rank_order(snapshot) == rank_order(shares),
      exit_sample_rank_agreement: rank_order(shares) == rank_order(frequencies)
    }
  end

  def run_scenario(seed, scenario, options) when scenario in [:S0, :S1] do
    total = options[:pre_ticks] + options[:post_ticks]
    initial = %{
      seed: seed,
      tick: 0,
      position: div(options[:world_max], 2),
      field: new_field(),
      traces: LocalTrace.new(),
      pending: [],
      history: []
    }

    state = Enum.reduce(1..total, initial, fn tick, state ->
      scenario_advance(state, tick, scenario, options)
    end)

    post = state.history |> Enum.reverse() |> Enum.filter(&(&1.phase == :post))
    counts = action_counts(post)
    corrected = Revision.behavioral_correct?(counts)

    %{
      schema_version: @schema_version,
      experiment_id: @experiment_id,
      component: "scenario",
      scenario_id: Atom.to_string(scenario),
      seed: seed,
      cumulative_intake: Enum.sum(Enum.map(post, & &1.intake_after)),
      mean_local_access: mean(Enum.map(post, & &1.access_after)),
      median_local_access: median(Enum.map(post, & &1.access_after)),
      source_contact_rate: Enum.count(post, &(&1.position_after == &1.source)) / max(length(post), 1),
      improvement_in_access_rate: Enum.count(post, &(&1.access_after > &1.access_before)) / max(length(post), 1),
      obsolete_action_rate: Map.get(counts, :left, 0) / max(length(post), 1),
      behavioral_corrected: corrected,
      expression_rate: (length(post) - Map.get(counts, :remain, 0)) / max(length(post), 1),
      post_position_counts:
        post
        |> Enum.frequencies_by(& &1.position_after)
        |> Map.new(fn {position, count} -> {Integer.to_string(position), count} end)
    }
  end

  defp transfer_rows(rows, options) do
    for row <- rows, boundary <- @boundaries do
      probe = probe_snapshot(Map.fetch!(row.support_snapshots, boundary), options[:probe_samples])

      %{
        schema_version: @schema_version,
        experiment_id: @experiment_id,
        component: "transfer",
        variant_id: row.variant_id,
        seed: row.seed,
        boundary: Atom.to_string(boundary),
        support: probe.support,
        resistance: probe.resistance,
        exit_activation: probe.exit_activation,
        exit_share: probe.exit_share,
        sampled_frequency: probe.sampled_frequency,
        support_exit_rank_agreement: probe.support_exit_rank_agreement,
        exit_sample_rank_agreement: probe.exit_sample_rank_agreement,
        gross_support_removed: row.total_support_removed,
        same_path_support_redeposited: row.five_tick_same_path_reinforcement,
        net_retained_weakening: row.total_support_removed - row.five_tick_same_path_reinforcement,
        observed_residue_change: row.net_support_change_after_recovery
      }
    end
  end

  defp scenario_rows(options) do
    seeds = options[:first_seed]..(options[:first_seed] + options[:samples] - 1)
    for scenario <- [:S0, :S1], seed <- seeds, do: run_scenario(seed, scenario, options)
  end

  defp summarize(transfer_rows, scenario_rows) do
    transfer_grouped = Enum.group_by(transfer_rows, & &1.variant_id)
    scenario_grouped = Enum.group_by(scenario_rows, & &1.scenario_id)

    transfer = Map.new(transfer_grouped, fn {id, rows} ->
      {id, %{
        support_exit_rank_agreement_rate: rate(rows, & &1.support_exit_rank_agreement),
        exit_sample_rank_agreement_rate: rate(rows, & &1.exit_sample_rank_agreement),
        saturated_rate: saturated_rate(rows),
        median_net_retained_weakening: median(Enum.map(rows, & &1.net_retained_weakening))
      }}
    end)

    scenarios = Map.new(scenario_grouped, fn {id, rows} ->
      {id, %{
        cumulative_intake_median: median(Enum.map(rows, & &1.cumulative_intake)),
        local_access_median: median(Enum.map(rows, & &1.median_local_access)),
        source_contact_rate_median: median(Enum.map(rows, & &1.source_contact_rate)),
        improvement_in_access_rate_median: median(Enum.map(rows, & &1.improvement_in_access_rate)),
        expression_rate_median: median(Enum.map(rows, & &1.expression_rate)),
        corrected: Enum.count(rows, & &1.behavioral_corrected)
      }}
    end)

    %{transfer: transfer, scenarios: scenarios}
  end

  defp saturated_rate(rows) do
    comparisons =
      for row <- rows,
          action <- @actions,
          abs(Map.get(row.support, action, 0.0)) >= 0.05 do
        abs(Map.get(row.exit_share, action, 0.0)) < 0.01
      end

    if comparisons == [], do: 0.0, else: Enum.count(comparisons, & &1) / length(comparisons)
  end

  defp scenario_advance(state, tick, scenario, options) do
    phase = if tick <= options[:pre_ticks], do: :pre, else: :post
    source = source(phase, scenario, options)
    intake_before = intake(state.position, source, options)
    access_before = access(state.position, source, options)
    {action, activation} = choose_action(state, tick)
    next_position = move(state.position, action, options)
    intake_after = intake(next_position, source, options)
    access_after = access(next_position, source, options)
    actual_delta = intake_after - intake_before
    experienced_delta = actual_delta + coincidence(state.seed, tick)

    traces = LocalTrace.decay(state.traces, factor: 0.72)
    action_key = {:action, tick, action}
    displacement_key = {:displacement, tick, sign(next_position - state.position)}
    traces = LocalTrace.activate(traces, action_key, 1.0)
    traces = if next_position == state.position, do: traces,
      else: LocalTrace.activate(traces, displacement_key, 1.0)

    effect = %{due: tick + 2, action: action, activation: activation,
      actual_delta: actual_delta, experienced_delta: experienced_delta,
      action_key: action_key, displacement_key: displacement_key}
    {due, pending} = Enum.split_with([effect | state.pending], &(&1.due <= tick))

    field = Enum.reduce(due, state.field, fn effect, field ->
      scale = min(LocalTrace.magnitude(traces, effect.action_key),
        LocalTrace.magnitude(traces, effect.displacement_key))

      cond do
        effect.experienced_delta > 1.0e-9 and scale > 0.0 and not is_nil(effect.activation) ->
          FlowLearning.apply(field, Map.take(effect.activation.flows, [{:strain, effect.action}]),
            deposit: 0.11 * scale, decay_slowing: 0.10, decay_scale: 0.0)
        effect.experienced_delta < -1.0e-9 and scale > 0.0 ->
          CognitiveField.disturb_terminal(field, [:strain, effect.action],
            magnitude: 0.16 * scale, fraction: 1.0)
        true -> field
      end
    end)

    entry = %{tick: tick, phase: phase, source: source, action: action,
      position_before: state.position, position_after: next_position,
      intake_before: intake_before, intake_after: intake_after,
      access_before: access_before, access_after: access_after,
      experienced_delta: experienced_delta}

    %{state | tick: tick, position: next_position, field: field, traces: traces,
      pending: pending, history: [entry | state.history]}
  end

  defp field_from_snapshot(snapshot) do
    Enum.reduce(@actions, CognitiveField.new(), fn action, field ->
      CognitiveField.add_transition(field, :strain, action,
        residue: Map.get(snapshot, action, 0.0))
    end)
  end

  defp new_field, do: field_from_snapshot(%{})

  defp choose_action(state, tick) do
    result = PermeableFlow.run(state.field, %{strain: 0.10}, @actions,
      threshold: 0.0001, attenuation: 0.995, permeability_scale: 0.32, max_ticks: 2)
    {weighted_action(result.exit_activation, {state.seed, tick}), result}
  end

  defp weighted_action(weights, seed) do
    entries = Enum.map(@actions, &{&1, max(0.0, Map.get(weights, &1, 0.0))})
    total = Enum.reduce(entries, 0.0, fn {_action, weight}, acc -> acc + weight end)
    if total <= 0.0, do: :remain, else: pick(entries, unit(seed) * total)
  end

  defp pick([{action, _}], _), do: action
  defp pick([{action, weight} | _], threshold) when threshold <= weight, do: action
  defp pick([{_, weight} | rest], threshold), do: pick(rest, threshold - weight)

  defp source(:pre, _scenario, _options), do: 0
  defp source(:post, :S0, options), do: options[:world_max]
  defp source(:post, :S1, options), do: options[:interior_source]

  defp intake(position, source, _options), do: max(0.0, 0.22 - 0.032 * abs(position - source))
  defp access(position, source, options),
    do: max(0.0, min(1.0, 1.0 - abs(position - source) / options[:world_max]))

  defp move(position, :left, _options), do: max(0, position - 1)
  defp move(position, :right, options), do: min(options[:world_max], position + 1)
  defp move(position, :remain, _options), do: position

  defp coincidence(seed, tick), do: if(unit({seed, tick, :coincidence}) < 0.18, do: 0.05, else: 0.0)
  defp unit(seed), do: :erlang.phash2(seed, 1_000_000) / 1_000_000
  defp sign(value) when value < 0, do: :negative
  defp sign(value) when value > 0, do: :positive
  defp sign(_), do: :none

  defp action_counts(history), do: Enum.frequencies_by(history, & &1.action)
  defp rank_order(map), do: @actions |> Enum.sort_by(&Map.get(map, &1, 0.0), :desc)
  defp rate(rows, predicate), do: Enum.count(rows, predicate) / max(length(rows), 1)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    Enum.at(sorted, div(length(sorted) - 1, 2)) * 1.0
  end

  defp revision_options(options) do
    [samples: options[:samples], first_seed: options[:first_seed],
     pre_ticks: options[:pre_ticks], post_ticks: options[:post_ticks],
     restoration_ticks: options[:restoration_ticks], window_ticks: options[:window_ticks]]
  end

  defp positive(options, keys) do
    case Enum.find(keys, &(not (is_integer(options[&1]) and options[&1] > 0))) do
      nil -> :ok
      key -> {:error, "#{key} must be a positive integer"}
    end
  end

  defp nonnegative(options, key) do
    if is_integer(options[key]) and options[key] >= 0, do: :ok,
      else: {:error, "#{key} must be a non-negative integer"}
  end

  defp interior(options) do
    if is_integer(options[:interior_source]) and options[:interior_source] > 0 and
         options[:interior_source] < options[:world_max], do: :ok,
      else: {:error, "interior_source must be strictly inside the world bounds"}
  end

  defp window(options) do
    if options[:window_ticks] <= options[:post_ticks], do: :ok,
      else: {:error, "window_ticks must not exceed post_ticks"}
  end
end