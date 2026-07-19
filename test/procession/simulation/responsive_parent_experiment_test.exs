defmodule Procession.Simulation.ResponsiveParentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ResponsiveParentExperiment, as: Experiment

  test "responsive parent world is deterministic" do
    opts = [ticks: 500, seed: 3]
    assert Experiment.run(opts) == Experiment.run(opts)
  end

  test "body remains bounded during responsive care" do
    state = Experiment.run(ticks: 500, seed: 4)
    child = state.child

    assert child.capacity >= 0.0 and child.capacity <= 1.0
    assert child.temperature >= 0.0 and child.temperature <= 1.0
    assert child.unresolved >= 0.0 and child.unresolved <= 1.0
    assert child.fatigue >= 0.0 and child.fatigue <= 1.0
  end

  test "responsive parent performs developmental interventions" do
    state = Experiment.run(ticks: 500, seed: 5)
    assert state.interventions > 0
  end
end
