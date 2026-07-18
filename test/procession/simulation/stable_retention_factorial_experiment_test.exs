defmodule Procession.Simulation.StableRetentionFactorialExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.StableRetentionFactorialExperiment, as: Experiment

  test "comparison covers all motor and plasticity combinations" do
    results = Experiment.compare(ticks: 60, seeds: Enum.to_list(1..4))

    for motor <- Experiment.motor_modes(), profile <- Experiment.profiles() do
      assert Map.has_key?(results, {motor, profile})
    end
  end

  test "stable source supports useful pathway acquisition" do
    results = Experiment.compare(ticks: 100, seeds: Enum.to_list(1..20))
    assert Enum.any?(results, fn {_key, summary} -> summary.acquired > 0 end)
  end

  test "fixed seeds produce repeatable results" do
    opts = [ticks: 80, seeds: Enum.to_list(1..10)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end
end
