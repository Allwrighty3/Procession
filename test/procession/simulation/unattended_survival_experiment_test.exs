defmodule Procession.Simulation.UnattendedSurvivalExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.UnattendedSurvivalExperiment

  test "body coupling produces unattended action and survival without teaching" do
    result = UnattendedSurvivalExperiment.run(population: 8, ticks: 80, seed: 1)

    uncoupled = result.conditions.uncoupled
    coupled = result.conditions.body_coupled

    assert uncoupled.survived == 0
    assert coupled.survived == 8
    assert uncoupled.median_self_originated_actions == 0.0
    assert coupled.median_self_originated_actions > 0.0
    assert coupled.median_intake > uncoupled.median_intake
    assert coupled.median_lifetime > uncoupled.median_lifetime
    assert coupled.median_motionless_fraction < uncoupled.median_motionless_fraction
  end

  test "probe is deterministic for a fixed seed" do
    first = UnattendedSurvivalExperiment.run(population: 4, ticks: 80, seed: 7)
    second = UnattendedSurvivalExperiment.run(population: 4, ticks: 80, seed: 7)

    assert first == second
  end

  test "report exposes survival and behavioral metrics" do
    report =
      [population: 4, ticks: 80, seed: 1]
      |> UnattendedSurvivalExperiment.run()
      |> UnattendedSurvivalExperiment.report()

    assert report =~ "Unattended developmental learner survival"
    assert report =~ "uncoupled:"
    assert report =~ "body_coupled:"
    assert report =~ "self_originated="
    assert report =~ "motionless="
    assert report =~ "body_coupling_delta:"
  end
end
