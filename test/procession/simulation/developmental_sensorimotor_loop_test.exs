defmodule Procession.Simulation.DevelopmentalSensorimotorLoopTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalMotorBody
  alias Procession.Simulation.DevelopmentalSensorimotorLoop

  @field_opts [
    micro_nodes: 64,
    input_width: 3,
    encoding_salt: :official_loop_test,
    output_source_threshold: 0.0,
    output_edge_retention: 1.0,
    output_plasticity_budget: 0.5
  ]

  @features [
    {:body_channel, :pressure, :high},
    {:visual_channel, :stimulus_relation, :near}
  ]

  test "field activity emits an opaque motor pattern through the body" do
    loop =
      DevelopmentalSensorimotorLoop.new(
        field_opts: @field_opts,
        body_opts: [initial_coordination: 1.0],
        position: {1, 1}
      )
      |> DevelopmentalSensorimotorLoop.sense(@features)

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
    assert emitted.last_tick == 1
    refute Map.has_key?(outcome, :action)
  end

  test "construction configuration remains authoritative when cycle callers omit it" do
    loop =
      DevelopmentalSensorimotorLoop.new(
        field_opts: @field_opts,
        body_opts: [initial_coordination: 1.0],
        position: {1, 1}
      )
      |> DevelopmentalSensorimotorLoop.sense(@features)

    {emitted, outcome} =
      DevelopmentalSensorimotorLoop.emit(loop, 2,
        seed: 4,
        bounds: {3, 3},
        output_exploration: 1.0
      )

    closed =
      DevelopmentalSensorimotorLoop.feedback(
        emitted,
        [{:proprioceptive_channel, :displacement, outcome.direction}],
        1.0
      )

    assert closed.pending_output == nil
    assert map_size(closed.field.output_edges) > 0
    assert Enum.any?(closed.field.output_edges, fn {{_source, output}, weight} ->
             output == outcome.pattern and weight > 0.0
           end)
  end

  test "learned relational support changes later motor selection" do
    base =
      DevelopmentalSensorimotorLoop.new(
        field_opts: @field_opts,
        body_opts: [initial_coordination: 1.0],
        position: {1, 1}
      )
      |> DevelopmentalSensorimotorLoop.sense(@features)

    {_baseline_loop, baseline_outcome} =
      DevelopmentalSensorimotorLoop.emit(base, 1,
        seed: 17,
        bounds: {3, 3},
        output_exploration: 0.0
      )

    {target, first_target_tick} =
      2..200
      |> Enum.map(fn tick ->
        {_loop, outcome} =
          DevelopmentalSensorimotorLoop.emit(base, tick,
            seed: 17,
            bounds: {3, 3},
            output_exploration: 1.0
          )

        {outcome.pattern, tick}
      end)
      |> Enum.find(fn {pattern, _tick} -> pattern != baseline_outcome.pattern end)

    trained =
      Enum.reduce(first_target_tick..(first_target_tick + 120), base, fn tick, loop ->
        loop = DevelopmentalSensorimotorLoop.sense(loop, @features)

        {emitted, outcome} =
          DevelopmentalSensorimotorLoop.emit(loop, tick,
            seed: 17,
            bounds: {3, 3},
            output_exploration: 1.0
          )

        coherence = if outcome.pattern == target, do: 1.0, else: -1.0

        DevelopmentalSensorimotorLoop.feedback(
          emitted,
          [{:proprioceptive_channel, :motor_consequence, outcome.consequence}],
          coherence
        )
      end)

    trained = DevelopmentalSensorimotorLoop.sense(trained, @features)

    {_trained_loop, learned_outcome} =
      DevelopmentalSensorimotorLoop.emit(trained, first_target_tick + 121,
        seed: 17,
        bounds: {3, 3},
        output_exploration: 0.0
      )

    assert target != baseline_outcome.pattern
    assert learned_outcome.pattern == target
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
        @features,
        3,
        feedback,
        seed: 5,
        bounds: {3, 3},
        output_exploration: 1.0
      )

    trace = DevelopmentalSensorimotorLoop.trace(loop)

    assert outcome.pattern in DevelopmentalMotorBody.patterns()
    assert trace.cycles == 1
    assert trace.motor_attempts == 1
    assert trace.pending_output == nil
    assert trace.last_tick == 3
    assert trace.last_outcome.pattern == outcome.pattern
    assert trace.learned_output_edges > 0
    assert trace.active_sensory_nodes > 0
  end

  test "feedback cannot be invented without an emitted bodily output" do
    loop = DevelopmentalSensorimotorLoop.new(field_opts: @field_opts)

    assert_raise ArgumentError, fn ->
      DevelopmentalSensorimotorLoop.feedback(loop, [], 1.0)
    end
  end

  test "a pending output cannot be overwritten before feedback" do
    loop =
      DevelopmentalSensorimotorLoop.new(field_opts: @field_opts)
      |> DevelopmentalSensorimotorLoop.sense(@features)

    {emitted, _outcome} =
      DevelopmentalSensorimotorLoop.emit(loop, 10,
        seed: 1,
        output_exploration: 1.0
      )

    assert_raise ArgumentError, fn ->
      DevelopmentalSensorimotorLoop.emit(emitted, 11)
    end
  end

  test "motor ticks must increase monotonically" do
    loop =
      DevelopmentalSensorimotorLoop.new(field_opts: @field_opts)
      |> DevelopmentalSensorimotorLoop.sense(@features)

    {emitted, outcome} =
      DevelopmentalSensorimotorLoop.emit(loop, 10,
        seed: 1,
        output_exploration: 1.0
      )

    closed =
      DevelopmentalSensorimotorLoop.feedback(
        emitted,
        [{:proprioceptive_channel, :motor_consequence, outcome.consequence}],
        0.0
      )

    assert_raise ArgumentError, fn ->
      DevelopmentalSensorimotorLoop.emit(closed, 10)
    end
  end
end
