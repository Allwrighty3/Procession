defmodule Procession.Simulation.LearnerOwnedAssistanceExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.LearnerOwnedAssistanceExperiment

  test "caregiver assistance activates learner-owned home-foraging actions" do
    result =
      LearnerOwnedAssistanceExperiment.run(
        population: 4,
        stage_ticks: 40,
        withdrawal_ticks: 8,
        seed: 1
      )

    abrupt = result.conditions.abrupt_assistance
    staged = result.conditions.staged_assistance

    assert result.home == {0, 0}
    assert abrupt.ownership == 1.0
    assert staged.ownership == 1.0
    assert abrupt.assistance > 0.0
    assert staged.assistance > 0.0
    assert abrupt.completed_cycles > 0
    assert staged.completed_cycles > 0
  end

  test "provision-only condition does not invent caregiver assistance" do
    result =
      LearnerOwnedAssistanceExperiment.run(
        population: 2,
        stage_ticks: 3,
        withdrawal_ticks: 3,
        seed: 2
      )

    provision = result.conditions.provision_only
    assert provision.ownership == 1.0
    assert provision.assistance == 0.0
  end
end
