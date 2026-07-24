defmodule Procession.Simulation.DevelopmentalSensorimotorLoopTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalMotorBody
  alias Procession.Simulation.DevelopmentalSensorimotorLoop

  @field_opts [micro_nodes: 64, input_width: 3, encoding_salt: :official_loop_test]

  test "field activity emits an opaque motor pattern through the body" do
    loop =
      DevelopmentalSensorimotorLoop.new(
        field_opts: @field_opts,
        body_opts: [initial_coordination: 1.0],
        position: {1, 1}
      )
      |> DevelopmentalSensorimotorLoop.sense(
        [{:visual_channel, :stimulus_relation, :near}],
        @field_opts
      )

    {emitted, outcome} =
      DevelopmentalSensorimotorLoop.emit(loop, 1,
        seed: 9,
        bounds: {3, 3},
        output_exploration: 1.0
      )

    assert outcome.pattern in DevelopmentalMotorBody.patterns()
    assert emitted.pending_output == outcome.pattern
    assert emitted.body.attempts == 1
    assert emitted.cycles == 1
    refute Map.has_key?(outcome, :action)
  end

  test "world feedback changes future field-to-output support through the sensory boundary" do
    opts =
      @field_opts ++
        [
          seed: 4,
          bounds: {3, 3},
          output_exploration: 1.0,
          output_source_threshold: 0.0,
          output_plasticity_budget: 0.5
        ]

    loop =
      DevelopmentalSensorimotorLoop.new(
        field_opts: @field_opts,
        body_opts: [initial_coordination: 1.0],
        position: {1, 1}
      )
      |> DevelopmentalSensorimotorLoop.sense(
        [
          {:body_channel, :pressure, :high},
          {:visual_channel, :stimulus_relation, :near}
        ],
        opts
      )

    {emitted, outcome} = DevelopmentalSensorimotorLoop.emit(loop, 2, opts)

    closed =
      DevelopmentalSensorimotorLoop.feedback(
        emitted,
        [{:proprioceptive_channel, :displacement, outcome.direction}],
        1.0,
        opts
      )

    assert closed.pending_output == nil
    assert map_size(closed.field.output_edges) > 0
    assert Enum.any?(closed.field.output_edges, fn {{_source, output}, weight} ->
             output == outcome.pattern and weight > 0.0
           end)
    assert closed.field.sensory.tick > loop.field.sensory.tick
  end

  test "cycle owns the complete field body world feedback sequence" do
    feedback = fn outcome, position ->
      features = [
        {:proprioceptive_channel, :motor_consequence, outcome.consequence},
        {:spatial_channel, :position, position}
      ]

      coherence = if outcome.displaced?, do: 1.0, else: -0.2
      {features, coherence}
    end

    {loop, outcome} =
      DevelopmentalSensorimotorLoop.new(
        field_opts: @field_opts,
        body_opts: [initial_coordination: 1.0],
        position: {1, 1}
      )
      |> DevelopmentalSensorimotorLoop.cycle(
        [{:visual_channel, :stimulus_relation, :near}],
        3,
        feedback,
        @field_opts ++
          [
            seed: 5,
            bounds: {3, 3},
            output_exploration: 1.0,
            output_source_threshold: 0.0
          ]
      )

    trace = DevelopmentalSensorimotorLoop.trace(loop)

    assert outcome.pattern in DevelopmentalMotorBody.patterns()
    assert trace.cycles == 1
    assert trace.motor_attempts == 1
    assert trace.pending_output == nil
    assert trace.last_outcome.pattern == outcome.pattern
    assert trace.learned_output_edges > 0
    assert trace.active_sensory_nodes > 0
  end

  test "feedback cannot be invented without an emitted bodily output" do
    loop = DevelopmentalSensorimotorLoop.new(field_opts: @field_opts)

    assert_raise ArgumentError, fn ->
      DevelopmentalSensorimotorLoop.feedback(loop, [], 1.0, @field_opts)
    end
  end
end
