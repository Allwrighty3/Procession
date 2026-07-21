defmodule Procession.Simulation.LearnerOwnedAssistanceExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.LearnerOwnedAssistanceExperiment

  test "caregiver assistance activates learner-owned actions" do
    result = LearnerOwnedAssistanceExperiment.run(
      population: 4,
      stage_ticks: 40,
      withdrawal_ticks: 4,
      seed: 1
    )

    abrupt = result.conditions.abrupt_assistance
    staged = result.conditions.staged_assistance

    assert abrupt.ownership == 1.0
    assert staged.ownership == 1.0
    assert abrupt.assistance > 0.0
    assert staged.assistance > 0.0
    assert abrupt.assisted > 0.0
    assert staged.assisted > 0.0
  end

  test "provision-only condition does not invent caregiver action" do
    result = LearnerOwnedAssistanceExperiment.run(
      population: 2,
      stage_ticks: 3,
      withdrawal_ticks: 3,
      seed: 2
    )

    provision = result.conditions.provision_only
    assert provision.ownership == 1.0
    assert provision.assistance == 0.0
    assert provision.assisted == 0.0
  end
end
