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

  test "regulation can leave cue-motor traces" do
    states = Enum.map(1..12, &Experiment.run(ticks: 900, seed: &1))
    assert Enum.any?(states, fn state -> map_size(state.child.cue_memory) > 0 end)
  end

  test "visible non-regulating caregiver leaves no reinforced cue memory" do
    states = Enum.map(1..12, fn seed ->
      Experiment.run(ticks: 900, seed: seed, caregiver_warmth: 0.0,
        caregiver_provision: 0.0, caregiver_recovery: 0.0)
    end)

    assert Enum.all?(states, fn state -> map_size(state.child.cue_memory) == 0 end)
  end

  test "population comparison is deterministic" do
    opts = [ticks: 600, seeds: Enum.to_list(1..5)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end
end
