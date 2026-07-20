defmodule Procession.Simulation.RevisionOpportunityAttributionFactorialExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.AssociationReversalExperiment
  alias Procession.Simulation.RevisionOpportunityAttributionFactorialExperiment, as: Experiment

  @small [samples: 2, first_seed: 1, control_pre_ticks: 30, control_post_ticks: 30,
          extended_post_ticks: 60, extended_pre_ticks: 60, window_ticks: 30]

  test "contains exactly the approved four variants with paired deterministic seeds" do
    result = Experiment.run(@small)
    assert Enum.map(Experiment.variant_specs(), & &1.id) == ["C0", "V1", "V2", "V3"]
    assert length(result.rows) == 8
    assert result.rows |> Enum.map(& &1.seed) |> Enum.chunk_every(2) == [[1, 2], [1, 2], [1, 2], [1, 2]]
  end

  test "uses declared schedules and reverses immediately after pre-reversal duration" do
    row = Experiment.run(@small).rows |> Enum.find(&(&1.variant_id == "V2" and &1.seed == 1))
    assert row.pre_reversal_ticks == 60
    assert row.post_reversal_ticks == 30
    assert row.total_ticks == 90
    assert Enum.sum(Map.values(row.pre_reversal_acquisition.actions)) == 60
  end

  test "100 samples produces exactly 400 stable ordered rows and deterministic replay" do
    opts = Keyword.put(@small, :samples, 100)
    first = Experiment.run(opts).rows
    second = Experiment.run(opts).rows
    assert length(first) == 400
    assert first == second
    assert Enum.take(first, 2) |> Enum.map(&{&1.variant_id, &1.seed}) == [{"C0", 1}, {"C0", 2}]
  end

  test "validates positive options and complete windows" do
    assert {:error, "samples must be a positive integer"} = Experiment.validate_options(samples: 0)
    assert {:error, "control_post_ticks must be divisible by window_ticks"} =
      Experiment.validate_options(control_post_ticks: 91)
  end

  test "behavioral correction boundary requires a strict right majority and obsolete rate at most one quarter" do
    assert Experiment.behavioral_correct?(%{left: 1, right: 3, remain: 0})
    refute Experiment.behavioral_correct?(%{left: 2, right: 2, remain: 0})
    refute Experiment.behavioral_correct?(%{left: 2, right: 3, remain: 3})
  end

  test "behavioral correction delay finds the first passing window and right-censors absent correction" do
    failed = [%{action: :left}, %{action: :remain}, %{action: :remain}, %{action: :remain}]
    corrected = [%{action: :right}, %{action: :right}, %{action: :remain}, %{action: :remain}]
    assert Experiment.behavioral_delay_for_windows([failed, corrected], 4, 8) == 5
    assert Experiment.behavioral_delay_for_windows([failed], 4, 4) == 5
  end

  test "normalized obsolete action rate uses all post-reversal actions" do
    assert Experiment.normalized_obsolete_action_rate([%{action: :left}, %{action: :right}, %{action: :remain}, %{action: :left}]) == 0.5
  end

  test "rows retain observer-only metrics, censored delays, normalized obsolete rate, and agreement" do
    row = Experiment.run(@small).rows |> hd()
    assert row.behavioral_correction_delay in 1..(row.post_reversal_ticks + 1)
    assert row.resistance_correction_delay in 1..(row.post_reversal_ticks + 1)
    assert row.normalized_obsolete_action_rate >= 0.0 and row.normalized_obsolete_action_rate <= 1.0
    assert row.metric_agreement in ["agree_corrected", "agree_not_corrected", "disagree"]
    assert length(row.post_reversal_windows) == div(row.post_reversal_ticks, row.window_ticks)
  end

  test "summary includes paired deltas and disagreement reporting" do
    summary = Experiment.run(@small).summary
    assert Map.has_key?(summary.paired_deltas, "C0_to_V1")
    assert summary.variants["C0"].metric_disagreement.denominator == 2
    assert is_boolean(summary.criteria.inconclusive)
  end

  test "metric task creates output directories and fails cleanly for invalid paths" do
    root = Path.join(System.tmp_dir!(), "procession-factorial-#{System.unique_integer([:positive])}")
    raw = Path.join(root, "nested/raw.jsonl")
    summary = Path.join(root, "nested/summary.txt")
    Mix.Task.reenable("procession.metrics.revision_opportunity_attribution")
    Mix.Tasks.Procession.Metrics.RevisionOpportunityAttribution.run([
      "--samples", "2", "--control-pre-ticks", "30", "--control-post-ticks", "30",
      "--extended-post-ticks", "60", "--extended-pre-ticks", "60", "--window-ticks", "30",
      "--output", raw, "--summary-output", summary
    ])
    assert File.exists?(raw)
    assert File.exists?(summary)
    assert length(File.read!(raw) |> String.split("\n", trim: true)) == 8
    assert_raise Mix.Error, ~r/could not write/, fn ->
      Mix.Task.reenable("procession.metrics.revision_opportunity_attribution")
      Mix.Tasks.Procession.Metrics.RevisionOpportunityAttribution.run(["--output", "/dev/null/raw.jsonl"])
    end
  end

  test "entity-visible association state contains no observer-only or forbidden fields" do
    state = AssociationReversalExperiment.run(seed: 1, ticks: 2, reversal_tick: 1)
    for field <- [:coordinates, :correct_action, :reversal_tick, :causal_explanation,
                  :counterfactual_provenance, :observer_accuracy, :cause_graph, :world_provenance] do
      refute Map.has_key?(state, field)
    end
  end
end
