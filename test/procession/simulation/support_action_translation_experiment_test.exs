defmodule Procession.Simulation.SupportActionTranslationExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.SupportActionTranslationExperiment, as: Experiment

  test "validates bounded options" do
    assert {:ok, _} = Experiment.validate_options(samples: 2, probe_samples: 20)
    assert {:error, _} = Experiment.validate_options(samples: 0)
    assert {:error, _} = Experiment.validate_options(interior_source: 0)
    assert {:error, _} = Experiment.validate_options(interior_source: 10)
  end

  test "frozen snapshot probe is deterministic and read only" do
    snapshot = %{left: 0.8, right: 0.2, remain: 0.1}
    first = Experiment.probe_snapshot(snapshot, 100)
    second = Experiment.probe_snapshot(snapshot, 100)

    assert first == second
    assert snapshot == %{left: 0.8, right: 0.2, remain: 0.1}
    assert first.support.left == 0.8
    assert first.resistance.left < first.resistance.right
    assert_in_delta Enum.sum(Map.values(first.exit_share)), 1.0, 1.0e-9
    assert_in_delta Enum.sum(Map.values(first.sampled_frequency)), 1.0, 1.0e-9
  end

  test "scenario evaluation is deterministic and changes only diagnostic schedule" do
    {:ok, options} = Experiment.validate_options(samples: 1, pre_ticks: 20, post_ticks: 30,
      restoration_ticks: 0, window_ticks: 10, probe_samples: 50)

    assert Experiment.run_scenario(7, :S0, options) == Experiment.run_scenario(7, :S0, options)
    assert Experiment.run_scenario(7, :S1, options) == Experiment.run_scenario(7, :S1, options)

    s0 = Experiment.run_scenario(7, :S0, options)
    s1 = Experiment.run_scenario(7, :S1, options)
    assert s0.seed == s1.seed
    assert s0.scenario_id == "S0"
    assert s1.scenario_id == "S1"
    assert s0.expression_rate >= 0.0
    assert s1.mean_local_access >= 0.0
  end

  test "emits exact deterministic transfer and scenario coverage" do
    first = Experiment.run(samples: 2, first_seed: 11, pre_ticks: 20, post_ticks: 30,
      restoration_ticks: 10, window_ticks: 10, probe_samples: 50)
    second = Experiment.run(samples: 2, first_seed: 11, pre_ticks: 20, post_ticks: 30,
      restoration_ticks: 10, window_ticks: 10, probe_samples: 50)

    assert first == second
    assert length(first.transfer_rows) == 24
    assert length(first.scenario_rows) == 4
    assert Enum.frequencies_by(first.transfer_rows, & &1.variant_id) ==
      %{"C0" => 6, "V1" => 6, "V2" => 6, "V3" => 6}
    assert Enum.frequencies_by(first.scenario_rows, & &1.scenario_id) == %{"S0" => 2, "S1" => 2}
  end

  test "support accounting remains in like-for-like units" do
    result = Experiment.run(samples: 1, pre_ticks: 20, post_ticks: 30,
      restoration_ticks: 10, window_ticks: 10, probe_samples: 20)

    for row <- result.transfer_rows do
      assert_in_delta row.net_retained_weakening,
        row.gross_support_removed - row.same_path_support_redeposited, 1.0e-12
      assert is_number(row.observed_residue_change)
    end
  end
end
