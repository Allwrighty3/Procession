defmodule Procession.Simulation.RelationalAttachmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationalAttachmentExperiment, as: Experiment

  test "field state remains bounded and structurally valid" do
    state = Experiment.run(ticks: 300, seed: 7)

    assert state.capacity >= 0.0 and state.capacity <= 1.0
    assert state.temperature >= 0.0 and state.temperature <= 1.0
    assert Enum.all?(state.field.activity, fn {_node, value} -> value >= 0.0 and value <= 1.0 end)
    assert Enum.all?(state.field.edges, fn {{_from, _to}, value} -> value >= 0.0 and value <= 3.0 end)
    assert Enum.all?(state.field.eligibility, fn {{_from, _to}, value} -> value >= 0.0 and value <= 2.0 end)
  end

  test "population comparison is deterministic" do
    opts = [ticks: 500, seeds: Enum.to_list(1..5)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end

  test "no-parent control does not receive caregiver regulation" do
    state = Experiment.run(ticks: 300, seed: 4, parent_mode: :none)

    refute Enum.any?(state.history, & &1.regulated)
    assert state.interventions == 0
  end
end
