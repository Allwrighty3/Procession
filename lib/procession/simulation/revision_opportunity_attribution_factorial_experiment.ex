defmodule Procession.Simulation.RevisionOpportunityAttributionFactorialExperiment do
  @moduledoc """
  Observer-only factorial over the existing association-reversal experiment.

  It changes only the pre- and post-reversal horizons and attribution variant.
  Correctness labels and aggregate diagnostics are constructed by this runner and
  are never supplied to the association-reversal entity state.
  """

  alias Procession.Simulation.AssociationReversalExperiment, as: Association

  @experiment_id "council_iteration_001_revision_opportunity_attribution_factorial"
  @schema_version 1

  @variant_specs [
    %{id: "C0", learner_variant: :local_adaptive, pre_key: :control_pre_ticks,
      post_key: :control_post_ticks},
    %{id: "V1", learner_variant: :local_adaptive, pre_key: :control_pre_ticks,
      post_key: :extended_post_ticks},
    %{id: "V2", learner_variant: :local_adaptive, pre_key: :extended_pre_ticks,
      post_key: :control_post_ticks},
    %{id: "V3", learner_variant: :outcome_adaptive, pre_key: :control_pre_ticks,
      post_key: :extended_post_ticks}
  ]

  @defaults [
    samples: 100,
    first_seed: 1,
    control_pre_ticks: 90,
    control_post_ticks: 90,
    extended_post_ticks: 180,
    extended_pre_ticks: 180,
    window_ticks: 30
  ]

  def experiment_id, do: @experiment_id
  def schema_version, do: @schema_version
  def defaults, do: @defaults
  def variant_specs, do: @variant_specs

  def validate_options(opts) do
    normalized = Keyword.merge(@defaults, opts)

    with :ok <- validate_positive(normalized, [:samples, :first_seed, :control_pre_ticks,
             :control_post_ticks, :extended_post_ticks, :extended_pre_ticks, :window_ticks]),
         :ok <- validate_windows(normalized) do
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

  def run_variant(%{id: id, learner_variant: learner_variant, pre_key: pre_key, post_key: post_key}, seed, options) do
    pre_ticks = Keyword.fetch!(options, pre_key)
    post_ticks = Keyword.fetch!(options, post_key)
    total_ticks = pre_ticks + post_ticks
    # Association reverses on `tick >= reversal_tick`; offset by one so the
    # declared pre-reversal duration contains exactly that many ticks.
    reversal_tick = pre_ticks + 1
    state = Association.run(variant: learner_variant, seed: seed, ticks: total_ticks, reversal_tick: reversal_tick)
    history = state.history |> Enum.reverse() |> Enum.sort_by(& &1.tick)
    pre_history = Enum.filter(history, &(&1.tick < reversal_tick))
    post_history = Enum.filter(history, &(&1.tick >= reversal_tick))
    window_ticks = options[:window_ticks]
    post_windows = windows(post_history, window_ticks)
    final_window = List.last(post_windows) || []
    final_counts = action_counts(final_window)
    behavioral_delay = behavioral_delay_for_history(post_history, window_ticks, post_ticks)
    behavioral_corrected = behavioral_delay <= post_ticks
    resistance_delay = if state.corrected_at, do: state.corrected_at - pre_ticks, else: post_ticks + 1
    resistance_corrected = resistance_delay <= post_ticks
    obsolete_rate = normalized_obsolete_action_rate(post_history)
    expression_rate = (length(post_history) - action_count(post_history, :remain)) / max(length(post_history), 1)
    attributions = state.correct_attributions + state.mistaken_attributions

    %{
      schema_version: @schema_version,
      experiment_id: @experiment_id,
      variant_id: id,
      learner_variant: Atom.to_string(learner_variant),
      seed: seed,
      pre_reversal_ticks: pre_ticks,
      post_reversal_ticks: post_ticks,
      total_ticks: total_ticks,
      window_ticks: window_ticks,
      pre_reversal_acquisition: %{
        actions: action_counts(pre_history),
        expression_rate: expression_rate(pre_history),
        positive_action_effects: Enum.count(pre_history, &(&1.actual_delta > 0.0))
      },
      post_reversal_windows: Enum.map(post_windows, &action_counts/1),
      behavioral_corrected: behavioral_corrected,
      behavioral_correction_delay_definition: "post_reversal_window_ending_tick",
      behavioral_correction_delay: behavioral_delay,
      resistance_corrected: resistance_corrected,
      resistance_correction_delay: resistance_delay,
      normalized_obsolete_action_rate: obsolete_rate,
      final_window_action_distribution: final_counts,
      post_reversal_expression_rate: expression_rate,
      attribution_diagnostics: %{
        attributions: attributions,
        correct_attributions: state.correct_attributions,
        mistaken_attributions: state.mistaken_attributions,
        misattribution_rate: state.mistaken_attributions / max(attributions, 1)
      },
      metric_agreement: agreement(behavioral_corrected, resistance_corrected)
    }
  end

  def summarize(rows, options) do
    by_variant = Enum.group_by(rows, & &1.variant_id)

    variants =
      Map.new(@variant_specs, fn %{id: id} ->
        variant_rows = Map.fetch!(by_variant, id)
        {id, variant_summary(variant_rows)}
      end)

    paired = %{
      "C0_to_V1" => paired_delta(Map.fetch!(by_variant, "C0"), Map.fetch!(by_variant, "V1")),
      "V1_to_V2" => paired_delta(Map.fetch!(by_variant, "V1"), Map.fetch!(by_variant, "V2")),
      "V1_to_V3" => paired_delta(Map.fetch!(by_variant, "V1"), Map.fetch!(by_variant, "V3"))
    }

    %{
      samples: options[:samples],
      variants: variants,
      paired_deltas: paired,
      criteria: criteria(variants),
      no_architectural_promotion: true
    }
  end

  def behavioral_correct?(counts), do: counts.right > counts.left and counts.left / max(total(counts), 1) <= 0.25

  @doc false
  def behavioral_delay_for_history(post_history, window_ticks, post_ticks) do
    case post_history |> Enum.chunk_every(window_ticks, 1, :discard) |> Enum.find_index(&(behavioral_correct?(action_counts(&1)))) do
      nil -> post_ticks + 1
      index -> index + window_ticks
    end
  end

  def normalized_obsolete_action_rate(history), do: action_count(history, :left) / max(length(history), 1)

  defp validate_positive(options, keys) do
    case Enum.find(keys, fn key -> not (is_integer(options[key]) and options[key] > 0) end) do
      nil -> :ok
      key -> {:error, "#{key} must be a positive integer"}
    end
  end

  defp validate_windows(options) do
    cond do
      rem(options[:control_post_ticks], options[:window_ticks]) != 0 ->
        {:error, "control_post_ticks must be divisible by window_ticks"}

      rem(options[:extended_post_ticks], options[:window_ticks]) != 0 ->
        {:error, "extended_post_ticks must be divisible by window_ticks"}

      true ->
        :ok
    end
  end

  defp windows(history, window_ticks), do: Enum.chunk_every(history, window_ticks)
  defp action_count(history, action), do: Enum.count(history, &(&1.action == action))
  defp action_counts(history), do: %{left: action_count(history, :left), right: action_count(history, :right), remain: action_count(history, :remain)}
  defp total(counts), do: counts.left + counts.right + counts.remain
  defp expression_rate(history), do: (length(history) - action_count(history, :remain)) / max(length(history), 1)

  defp agreement(true, true), do: "agree_corrected"
  defp agreement(false, false), do: "agree_not_corrected"
  defp agreement(_, _), do: "disagree"

  defp variant_summary(rows) do
    delays = Enum.map(rows, & &1.behavioral_correction_delay)
    obsolete = Enum.map(rows, & &1.normalized_obsolete_action_rate)
    disagreements = Enum.count(rows, &(&1.metric_agreement == "disagree"))
    %{
      behavioral_corrected: count_rate(rows, & &1.behavioral_corrected),
      resistance_corrected: count_rate(rows, & &1.resistance_corrected),
      behavioral_delay: distribution(delays),
      resistance_delay: distribution(Enum.map(rows, & &1.resistance_correction_delay)),
      obsolete_action_rate: distribution(obsolete),
      metric_disagreement: %{count: disagreements, denominator: length(rows), rate: disagreements / max(length(rows), 1)}
    }
  end

  defp count_rate(rows, predicate) do
    count = Enum.count(rows, predicate)
    %{count: count, denominator: length(rows), rate: count / max(length(rows), 1)}
  end

  defp distribution(values) do
    sorted = Enum.sort(values)
    %{median: percentile(sorted, 0.5), iqr: [percentile(sorted, 0.25), percentile(sorted, 0.75)]}
  end

  defp percentile([], _), do: 0.0
  defp percentile(values, fraction), do: Enum.at(values, round((length(values) - 1) * fraction)) * 1.0

  defp paired_delta(from_rows, to_rows) do
    from = Map.new(from_rows, &{&1.seed, &1})

    behavioral =
      paired_counts(to_rows, from, fn before_row, after_row ->
        case {before_row.behavioral_corrected, after_row.behavioral_corrected} do
          {false, true} -> :improved
          {true, false} -> :worsened
          _ -> :tied
        end
      end)

    obsolete_action_rate =
      paired_counts(to_rows, from, fn before_row, after_row ->
        compare_numeric(after_row.normalized_obsolete_action_rate, before_row.normalized_obsolete_action_rate)
      end)

    %{behavioral_correction: behavioral, normalized_obsolete_action_rate: obsolete_action_rate}
  end

  defp paired_counts(rows, before_by_seed, comparison) do
    counts = Enum.frequencies_by(rows, fn row -> comparison.(Map.fetch!(before_by_seed, row.seed), row) end)
    %{improved: Map.get(counts, :improved, 0), tied: Map.get(counts, :tied, 0),
      worsened: Map.get(counts, :worsened, 0), denominator: length(rows)}
  end

  defp compare_numeric(after_value, before_value) when after_value < before_value, do: :improved
  defp compare_numeric(after_value, before_value) when after_value > before_value, do: :worsened
  defp compare_numeric(_after_value, _before_value), do: :tied

  defp criteria(variants) do
    c0 = variants["C0"]
    v1 = variants["V1"]
    v2 = variants["V2"]
    v3 = variants["V3"]
    success = v1.behavioral_corrected.rate - c0.behavioral_corrected.rate >= 0.20 and
      c0.obsolete_action_rate.median - v1.obsolete_action_rate.median >= 0.20 and
      v1.behavioral_corrected.rate - v2.behavioral_corrected.rate >= 0.15 and
      v1.metric_disagreement.rate <= 0.15
    failure = v1.behavioral_corrected.rate - c0.behavioral_corrected.rate < 0.10 and
      c0.obsolete_action_rate.median - v1.obsolete_action_rate.median < 0.10 and
      v1.behavioral_corrected.rate - v2.behavioral_corrected.rate < 0.10
    attribution = v1.behavioral_corrected.rate - v3.behavioral_corrected.rate >= 0.20 and
      v3.obsolete_action_rate.median - v1.obsolete_action_rate.median >= 0.15
    measurement_disagreement = v1.metric_disagreement.rate > 0.15
    clean_success = success and not measurement_disagreement
    clean_failure = failure and not measurement_disagreement
    %{definitions: %{
        success: "V1-C0 correction >= 0.20; C0-V1 median obsolete >= 0.20; V1-V2 correction >= 0.15; V1 disagreement <= 0.15",
        failure: "V1-C0 correction < 0.10; C0-V1 median obsolete < 0.10; V1-V2 correction < 0.10",
        attribution_dominance: "V1-V3 correction >= 0.20; V3-V1 median obsolete >= 0.15",
        measurement_disagreement: "V1 behavioral and resistance classifications disagree in more than 15% of histories",
        inconclusive: "no clean success or failure, or measurement disagreement is flagged"
      }, success: clean_success, failure: clean_failure, attribution_dominance: attribution,
      measurement_disagreement: measurement_disagreement,
      inconclusive: not clean_success and not clean_failure}
  end
end
