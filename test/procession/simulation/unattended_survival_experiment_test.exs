defmodule Procession.Simulation.UnattendedSurvivalExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.UnattendedSurvivalExperiment

  test "probe records both unattended learner conditions" do
    result = UnattendedSurvivalExperiment.run(population: 4, ticks: 80, seed: 1)

    assert result.population == 4
    assert result.ticks == 80
    assert Map.has_key?(result.conditions, :uncoupled)
    assert Map.has_key?(result.conditions, :body_coupled)
    assert is_number(result.delta.lifetime)
    assert is_number(result.delta.intake)
    assert is_number(result.delta.motionless_fraction)
    assert is_number(result.delta.self_originated_actions)
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
