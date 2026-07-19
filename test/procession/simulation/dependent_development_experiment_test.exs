defmodule Procession.Simulation.DependentDevelopmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DependentDevelopmentExperiment

  test "experiment is deterministic and reports all phases" do
    opts = [population: 4, baby_ticks: 30, participation_ticks: 30, withdrawal_ticks: 20, seed: 7]
    first = DependentDevelopmentExperiment.run(opts)
    second = DependentDevelopmentExperiment.run(opts)

    assert first == second

    report = DependentDevelopmentExperiment.report(first)
    assert report =~ "Dependent 4x4 developmental learner"
    assert report =~ "orphan:"
    assert report =~ "maintained_only:"
    assert report =~ "participatory:"
    assert report =~ "contingent:"
    assert report =~ "baby_survived="
    assert report =~ "withdrawal_intake="
  end

  test "conditions expose comparable developmental metrics" do
    result = DependentDevelopmentExperiment.run(
      population: 4, baby_ticks: 30, participation_ticks: 30, withdrawal_ticks: 20, seed: 1)

    for condition <- [:orphan, :maintained_only, :participatory, :contingent] do
      summary = Map.fetch!(result.conditions, condition)
      assert summary.baby_survived >= 0
      assert summary.participation_survived >= 0
      assert summary.withdrawal_survived >= 0
      assert summary.median_lifetime >= 0.0
      assert summary.median_nodes >= 0.0
    end
  end
end
