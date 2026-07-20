defmodule Procession.Simulation.RevisionDisplacementFactorialExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.AssociationReversalExperiment, as: Baseline
  alias Procession.Simulation.RevisionDisplacementFactorialExperiment, as: Experiment

  test "validates bounded options" do
    assert {:ok, _} = Experiment.validate_options(samples: 2, competition_fraction: 0.25)
    assert {:error, _} = Experiment.validate_options(samples: 0)
    assert {:error, _} = Experiment.validate_options(restoration_ticks: -1)
    assert {:error, _} = Experiment.validate_options(competition_fraction: 1.1)
  end

  test "C0 reproduces the existing local-adaptive action and world stream" do
    {:ok, options} = Experiment.validate_options(samples: 1, pre_ticks: 30, post_ticks: 30,
      restoration_ticks: 0, window_ticks: 10)
    spec = Enum.find(Experiment.variant_specs(), &(&1.id == "C0"))
    state = Experiment.run_state(spec, 7, options)
    baseline = Baseline.run(variant: :local_adaptive, seed: 7, ticks: 60, reversal_tick: 31)

    actual = state.history |> Enum.reverse() |> Enum.map(&Map.take(&1, [:tick, :action, :actual_delta, :experienced_delta]))
    expected = baseline.history |> Enum.reverse() |> Enum.map(&Map.take(&1, [:tick, :action, :actual_delta, :experienced_delta]))
    assert actual == expected
  end

  test "V1 changes only the fixed disturbance factor" do
    [c0, v1 | _] = Experiment.variant_specs()
    assert c0.disturbance_factor == 1.0
    refute c0.competition?
    assert v1.disturbance_factor == 2.0
    refute v1.competition?
  end

  test "competition is finite and support conserving" do
    result = Experiment.run(samples: 3, pre_ticks: 20, post_ticks: 30,
      restoration_ticks: 10, window_ticks: 10)

    for row <- result.rows, row.competition_enabled do
      assert row.total_displaced_support <= row.successful_competing_deposit * 0.25 + 1.0e-9
      assert row.total_displaced_support >= 0.0
    end
  end

  test "emits balanced deterministic rows" do
    first = Experiment.run(samples: 4, first_seed: 11, pre_ticks: 20, post_ticks: 30,
      restoration_ticks: 10, window_ticks: 10)
    second = Experiment.run(samples: 4, first_seed: 11, pre_ticks: 20, post_ticks: 30,
      restoration_ticks: 10, window_ticks: 10)

    assert first == second
    assert length(first.rows) == 16
    assert Enum.frequencies_by(first.rows, & &1.variant_id) == %{"C0" => 4, "V1" => 4, "V2" => 4, "V3" => 4}
    assert Enum.sort(Enum.uniq(Enum.map(first.rows, & &1.seed))) == [11, 12, 13, 14]
  end

  test "restoration and accounting fields remain observer diagnostics" do
    result = Experiment.run(samples: 1, pre_ticks: 20, post_ticks: 30,
      restoration_ticks: 10, window_ticks: 10)

    for row <- result.rows do
      assert is_map(row.support_snapshots)
      assert Map.has_key?(row.support_snapshots, :pre_end)
      assert Map.has_key?(row.support_snapshots, :post_end)
      assert Map.has_key?(row.support_snapshots, :restoration_end)
      assert row.disturbance_event_count >= 0
      assert row.five_tick_recovery_ratio >= 0.0
      assert row.metric_agreement in ["agree_corrected", "agree_not_corrected", "disagree"]
    end
  end
end
