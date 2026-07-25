defmodule Procession.Simulation.LiveSensorimotorTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.LiveSensorimotor

  @field_opts [micro_nodes: 64, input_width: 3, encoding_salt: :live_sensorimotor_test]

  test "owns persistent sensorimotor state for one entity" do
    assert {:ok, process} =
             LiveSensorimotor.start_link(
               entity_id: "npc_learner",
               owner_pid: self(),
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

    opts = [
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
    assert LiveSensorimotor.trace(process).attached?
  end

  test "two-phase handshake leaves physical resolution outside the mental owner" do
    assert {:ok, process} =
             LiveSensorimotor.start_link(
               entity_id: "npc_world_handshake",
               owner_pid: self(),
               loop_opts: [
                 field_opts: @field_opts,
                 body_opts: [initial_coordination: 1.0],
                 position: {1, 1}
               ]
             )

    assert {:ok, emission} =
             LiveSensorimotor.emit(
               process,
               [{:signal, :nearby_resource, 2.0}],
               1,
               seed: 4,
               bounds: {3, 3},
               output_exploration: 1.0
             )

    assert LiveSensorimotor.trace(process).pending_output == emission.outcome.pattern

    resolved_position = {1, 1}

    assert {:ok, resolved} =
             LiveSensorimotor.resolve(
               process,
               resolved_position,
               [
                 {:position, resolved_position},
                 {:signal, {:body, :resistance}, 2.0}
               ],
               -0.2
             )

    assert resolved.position == resolved_position
    assert resolved.pending_output == nil
    assert resolved.cycles == 1
    assert resolved.learned_output_edges > 0
  end

  test "world feedback failure preserves the pending consequence for recovery" do
    assert {:ok, process} =
             LiveSensorimotor.start_link(
               entity_id: "npc_feedback_recovery",
               owner_pid: self(),
               loop_opts: [
                 field_opts: @field_opts ++ [output_source_threshold: 0.0],
                 body_opts: [initial_coordination: 1.0],
                 position: {1, 1}
               ]
             )

    failing_feedback = fn _outcome, _position -> raise "world unavailable" end

    assert {:error, {:feedback_failed, {:exception, "world unavailable"}, outcome}} =
             LiveSensorimotor.cycle(
               process,
               [{:visual_channel, :stimulus_relation, :near}],
               1,
               failing_feedback,
               seed: 3,
               bounds: {3, 3},
               output_exploration: 1.0
             )

    assert Process.alive?(process)
    assert LiveSensorimotor.trace(process).pending_output == outcome.pattern

    assert {:ok, recovered_trace} =
             LiveSensorimotor.feedback(
               process,
               [{:proprioceptive_channel, :consequence, outcome.consequence}],
               1.0
             )

    assert recovered_trace.pending_output == nil
    assert recovered_trace.learned_output_edges > 0

    assert {:ok, next_cycle} =
             LiveSensorimotor.cycle(
               process,
               [{:visual_channel, :stimulus_relation, :near}],
               2,
               fn next_outcome, _position ->
                 {[{:proprioceptive_channel, :consequence, next_outcome.consequence}], 0.0}
               end,
               seed: 3,
               bounds: {3, 3},
               output_exploration: 1.0
             )

    assert next_cycle.trace.cycles == 2
  end
end
