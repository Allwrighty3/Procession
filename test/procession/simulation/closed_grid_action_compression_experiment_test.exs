defmodule Procession.Simulation.ClosedGridActionCompressionExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ClosedGridActionCompressionExperiment, as: Experiment

  test "exposes explicit movement, consumption, and recovery actions" do
    assert Enum.sort(Experiment.actions()) == Enum.sort([:north, :south, :east, :west, :consume, :rest])
  end

  test "world-generated internal events discover reusable action assemblies" do
    state = Experiment.run(ticks: 500, initial_energy: 0.35)
    instrumentation = Experiment.instrumentation(state)

    assert instrumentation.event_count > 0
    assert instrumentation.assembly_count > 0
    assert instrumentation.transitions_saved > 0
    assert instrumentation.compression_ratio < 1.0
    assert Map.fetch!(instrumentation.action_counts, :consume) > 0
    assert Map.fetch!(instrumentation.action_counts, :rest) > 0
  end

  test "compression includes locomotion and consumption patterns rather than one homogeneous chain" do
    state = Experiment.run(ticks: 500, initial_energy: 0.35)
    members = Experiment.assemblies(state) |> Enum.flat_map(& &1.members)

    assert Enum.any?(members, &match?({:recruit, :locomotion}, &1))
    assert Enum.any?(members, &match?({:execute, :consume}, &1))
  end

  test "all positions remain inside the 4x4 world" do
    state = Experiment.run(ticks: 300)

    assert Enum.all?(state.history, fn entry ->
      {x, y} = entry.position
      x in 0..3 and y in 0..3
    end)
  end
end
