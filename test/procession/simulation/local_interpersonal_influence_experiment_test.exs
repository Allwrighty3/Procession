defmodule Procession.Simulation.LocalInterpersonalInfluenceExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.LocalInterpersonalInfluenceExperiment

  test "grounded nearby presence and observed action shape directed mental support" do
    result = LocalInterpersonalInfluenceExperiment.run(cycles: 48, seed: 19)

    assert result.experiment == :local_interpersonal_influence
    assert result.grounded_presence != []
    assert result.observed_event_signature == {:displacement, :east}
    assert result.social_relation_count == 1
    assert result.relation.confidence > 0.0
    assert result.relation.exposure > 0.0
    assert result.learned_output_edges > 0
    assert result.active_sensory_nodes > 0
    refute result.named_social_conclusions_present?
  end

  test "the result reports behavioral divergence rather than requiring it" do
    result = LocalInterpersonalInfluenceExperiment.run(cycles: 24, seed: 7)

    assert is_boolean(result.motor_pattern_changed?)
    assert is_tuple(result.baseline_motor_pattern)
    assert is_tuple(result.influenced_motor_pattern)
    assert is_tuple(result.target_motor_pattern)
  end
end