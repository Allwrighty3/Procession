defmodule Procession.Simulation.LocalInterpersonalControlsExperimentTest do
  use ExUnit.Case, async: true
  alias Procession.Simulation.LocalInterpersonalControlsExperiment

  test "grounded observation controls isolate local directed learning" do
    result = LocalInterpersonalControlsExperiment.run(cycles: 32, seed: 41)

    assert result.scenarios.absent.relation_count == 0
    assert result.scenarios.out_of_range.relation_count == 0
    assert result.scenarios.consistent.relation_count > 0
    assert result.scenarios.stationary.relation_count > 0
    assert result.grounded_effect_present?
    assert result.actor_specific?
    assert result.reversal_observed?
    refute result.named_social_conclusions_present?
  end
end
