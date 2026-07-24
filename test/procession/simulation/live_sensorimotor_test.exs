defmodule Procession.Simulation.LiveSensorimotorTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.LiveSensorimotor

  @field_opts [micro_nodes: 64, input_width: 3, encoding_salt: :live_sensorimotor_test]

  test "owns persistent sensorimotor state for one entity" do
    assert {:ok, process} =
             LiveSensorimotor.start_link(
               entity_id: "npc_learner",
               loop_opts: [
                 field_opts: @field_opts,
                 body_opts: [initial_coordination: 1.0],
                 position: {1, 1}
               ]
             )

    feedback = fn outcome, position ->
      features = [
        {:proprioceptive_channel, :consequence, outcome.consequence},
        {:spatial_channel, :position, position}
      ]

      {features, if(outcome.displaced?, do: 1.0, else: -0.2)}
    end

    opts =
      @field_opts ++
        [
          seed: 7,
          bounds: {3, 3},
          output_exploration: 1.0,
          output_source_threshold: 0.0
        ]

    assert {:ok, first} =
             LiveSensorimotor.cycle(
               process,
               [{:visual_channel, :stimulus_relation, :near}],
               1,
               feedback,
               opts
             )

    assert {:ok, second} =
             LiveSensorimotor.cycle(
               process,
               [{:visual_channel, :stimulus_relation, :near}],
               2,
               feedback,
               opts
             )

    assert first.entity_id == "npc_learner"
    assert second.entity_id == "npc_learner"
    assert second.trace.cycles == 2
    assert second.trace.motor_attempts == 2
    assert second.trace.learned_output_edges > 0
    assert LiveSensorimotor.entity_id(process) == "npc_learner"
    assert LiveSensorimotor.trace(process).cycles == 2
  end
end
