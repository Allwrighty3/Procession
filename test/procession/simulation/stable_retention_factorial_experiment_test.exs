defmodule Procession.Simulation.StableRetentionFactorialExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.StableContingencyFactorialExperiment, as: Experiment

  test "comparison covers all motor and plasticity combinations" do
    results = Experiment.compare(ticks: 60, seeds: Enum.to_list(1..4))

    for motor <- Experiment.motor_modes(), profile <- Experiment.profiles() do
      assert Map.has_key?(results, {motor, profile})
    end
  end

  test "fixed useful contingency supports pathway acquisition" do
    results = Experiment.compare(ticks: 100, seeds: Enum.to_list(1..20))
    assert Enum.any?(results, fn {_key, summary} -> summary.acquired > 0 end)
  end

  test "late behavior accounts for useful, harmful, and inactive outcomes" do
    results = Experiment.compare(ticks: 80, acquisition_window: 40, seeds: Enum.to_list(1..8))

    Enum.each(results, fn {_key, summary} ->
      total =
        summary.median_late_useful_fraction +
          summary.median_late_harmful_fraction +
          summary.median_late_inactive_fraction

      assert_in_delta total, 1.0, 0.05
    end)
  end

  test "fixed seeds produce repeatable results" do
    opts = [ticks: 80, seeds: Enum.to_list(1..10)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end
end
