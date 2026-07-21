defmodule Procession.Simulation.FadingAssistanceActionCostTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.FadingAssistanceExperiment

  test "action costs preserve a paired control and charge learner-owned withdrawal actions" do
    comparison =
      FadingAssistanceExperiment.compare_action_costs(
        population: 4,
        stage_ticks: 8,
        withdrawal_ticks: 20,
        seed: 7
      )

    refute comparison.control.action_costs
    assert comparison.action_cost.action_costs

    for condition <- [:provision_only, :abrupt_guidance, :staged_fading] do
      control = Map.fetch!(comparison.control.conditions, condition)
      treatment = Map.fetch!(comparison.action_cost.conditions, condition)

      assert control.median_withdrawal_cost == 0.0
      assert treatment.median_withdrawal_cost > 0.0
    end
  end
end