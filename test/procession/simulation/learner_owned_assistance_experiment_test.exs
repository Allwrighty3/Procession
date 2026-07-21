defmodule Procession.Simulation.LearnerOwnedAssistanceExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.LearnerOwnedAssistanceExperiment

  test "caregiver assistance activates learner-owned actions" do
    result = LearnerOwnedAssistanceExperiment.run(
      population: 4,
      stage_ticks: 4,
      withdrawal_ticks: 4,
      seed: 1
    )

    abrupt = result.conditions.abrupt_assistance
    staged = result.conditions.staged_assistance

    assert abrupt.median_ownership == 1.0
    assert staged.median_ownership == 1.0
    assert abrupt.median_assistance > 0.0
    assert staged.median_assistance > 0.0
    assert abrupt.median_assisted_actions > 0.0
    assert staged.median_assisted_actions > 0.0
  end

  test "provision-only condition does not invent caregiver action" do
    result = LearnerOwnedAssistanceExperiment.run(
      population: 2,
      stage_ticks: 3,
      withdrawal_ticks: 3,
      seed: 2
    )

    provision = result.conditions.provision_only
    assert provision.median_ownership == 1.0
    assert provision.median_assistance == 0.0
    assert provision.median_assisted_actions == 0.0
  end
end
