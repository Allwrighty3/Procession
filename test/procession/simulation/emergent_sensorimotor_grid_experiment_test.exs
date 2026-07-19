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
  end

  test "anonymous outputs affect hidden world physics" do
    state = Experiment.run(ticks: 160)
    metrics = Experiment.instrumentation(state)

    assert state.tick > 0
    assert map_size(state.visits) > 1
    assert Enum.sum(Map.values(metrics.output_usage)) > 0
    assert Map.get(metrics.world_effects, :displaced, 0) > 0
  end

  test "raw sensorimotor experience produces compression candidates" do
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
