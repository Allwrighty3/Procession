defmodule Procession.Simulation.UntaughtGridLearningExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.UntaughtGridLearningExperiment

  test "runs deterministically for a fixed seed" do
    opts = [population: 4, ticks: 80, training_ticks: 50, seed: 7]
    assert UntaughtGridLearningExperiment.run(opts) ==
             UntaughtGridLearningExperiment.run(opts)
  end

  test "reports all four conditions and withdrawal metrics" do
    result = UntaughtGridLearningExperiment.run(population: 4, ticks: 80, training_ticks: 50, seed: 1)
    report = UntaughtGridLearningExperiment.report(result)

    assert Map.keys(result.conditions) |> Enum.sort() ==
             [:contingent, :inert, :pressure_only, :provisioned]
    assert report =~ "Untaught 4x4 developmental learner"
    assert report =~ "pressure_only:"
    assert report =~ "withdrawal_survived="
    assert report =~ "withdrawal_intake="
    assert report =~ "nodes="
  end

  test "inert condition remains a valid no-pressure control" do
    result = UntaughtGridLearningExperiment.run(population: 4, ticks: 60, training_ticks: 40, seed: 1)
    inert = result.conditions.inert

    assert inert.median_self_originated_actions >= 0.0
    assert inert.median_motionless_fraction >= 0.0
    assert inert.median_motionless_fraction <= 1.0
  end
end
