defmodule Procession.Simulation.EmbodiedAttachmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.EmbodiedAttachmentExperiment, as: Experiment

  test "body state remains bounded" do
    state = Experiment.run(ticks: 300, seed: 3)
    child = state.child

    assert child.capacity >= 0.0 and child.capacity <= 1.0
    assert child.temperature >= 0.0 and child.temperature <= 1.0
    assert child.fatigue >= 0.0 and child.fatigue <= 1.0
    assert child.strain >= 0.0 and child.strain <= 1.0
    assert child.unresolved >= 0.0 and child.unresolved <= 1.0
  end

  test "population comparison is deterministic" do
    opts = [ticks: 600, seeds: Enum.to_list(1..5)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end

  test "parent removal produces a valid no-caregiver control" do
    state = Experiment.run(ticks: 120, seed: 4, parent_departure: 0)
    refute state.parent_present
    assert state.history |> Enum.all?(fn entry -> is_nil(entry.parent) end)
  end
end
