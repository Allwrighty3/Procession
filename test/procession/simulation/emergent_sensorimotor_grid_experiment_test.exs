defmodule Procession.Simulation.EmergentSensorimotorGridExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.EmergentSensorimotorGridExperiment, as: Experiment

  test "entity-facing history contains no directions, actions, resources, or coordinates" do
    state = Experiment.run(ticks: 40)
    text = inspect(Enum.reverse(state.sensory_history))

    refute text =~ "north"
    refute text =~ "south"
    refute text =~ "east"
    refute text =~ "west"
    refute text =~ "consume"
    refute text =~ "rest"
    refute text =~ "resource"
    refute text =~ "position"
    refute text =~ "location"
  end

  test "anonymous outputs affect hidden world physics" do
    state = Experiment.run(ticks: 160)
    metrics = Experiment.instrumentation(state)

    assert state.tick > 0
    assert map_size(state.visits) > 1
    assert Enum.sum(Map.values(metrics.output_usage)) > 0
    assert Map.get(metrics.world_effects, :displaced, 0) > 0
  end

  test "panoramic vision exposes sixteen uninterpreted channels and distinguishes places" do
    left = Experiment.run(ticks: 1, initial_position: {0, 0}, exploration: 0.0)
    right = Experiment.run(ticks: 1, initial_position: {3, 3}, exploration: 0.0)

    assert map_size(left.previous_senses.vision) == 16
    assert map_size(right.previous_senses.vision) == 16
    refute left.previous_senses.vision == right.previous_senses.vision

    assert Enum.count(left.sensory_history, fn
             {:sense, :vision, _channel, _value} -> true
             _ -> false
           end) == 16
  end

  test "movement produces proprioceptive feedback and grid edges produce impact feedback" do
    state = Experiment.run(ticks: 320)
    metrics = Experiment.instrumentation(state)

    assert Enum.any?(state.hidden_history, fn event -> event.proprioception != {0.0, 0.0} end)
    assert Enum.sum(Map.values(metrics.boundary_impacts)) > 0

    assert Enum.any?(state.sensory_history, fn
             {:sense, :impact, _channel, value} when value > 0 -> true
             _ -> false
           end)
  end

  test "rising food signal reinforces the preceding anonymous outputs" do
    state = Experiment.run(ticks: 160)

    assert Enum.any?(state.hidden_history, fn event -> event.appetitive_feedback > 0.0 end)
    assert state.appetitive_feedback != 0.0
    assert Enum.any?(Map.values(state.tendencies), &(&1 != 0.0))
  end

  test "mouth watering pressure increases with energy deficit" do
    fed = Experiment.run(ticks: 1, initial_position: {0, 0}, initial_energy: 0.90)
    depleted = Experiment.run(ticks: 1, initial_position: {0, 0}, initial_energy: 0.25)

    fed_pressure = hd(fed.hidden_history).mouth_watering
    depleted_pressure = hd(depleted.hidden_history).mouth_watering

    assert fed_pressure > 0.0
    assert depleted_pressure > fed_pressure
  end

  test "appetitive coupling can produce intake without an entity-facing consume action" do
    state = Experiment.run(ticks: 320)
    metrics = Experiment.instrumentation(state)

    assert Map.get(metrics.world_effects, :intake, 0) > 0
    assert metrics.intake > 0.0
  end

  test "raw multisensory experience produces compression candidates" do
    state = Experiment.run(ticks: 320)
    metrics = Experiment.instrumentation(state)

    assert metrics.tracked_motifs > 0
    assert metrics.assembly_count > 0
    assert metrics.transitions_saved > 0
  end

  test "run is deterministic for the same options" do
    left = Experiment.run(ticks: 120)
    right = Experiment.run(ticks: 120)

    assert Experiment.instrumentation(left) == Experiment.instrumentation(right)
  end
end
