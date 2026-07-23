defmodule Procession.Simulation.RecursiveMemoryQualityExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.DevelopmentalField
  alias Procession.Simulation.DevelopmentalMemoryQuality
  alias Procession.Simulation.RecursiveMemoryQualityExperiment, as: Experiment

  test "quality gate removes trivial single-ancestor wrappers" do
    before = DevelopmentalField.new(micro_nodes: 4)
    child = %DevelopmentalField.Node{id: 4, kind: :generated,
      support: MapSet.new([0, 1]), compression_gain: 8.0}
    wrapper = %DevelopmentalField.Node{id: 5, kind: :generated,
      support: MapSet.new([4, 2]), compression_gain: 9.0}

    before = %{before | next_id: 5, nodes: Map.put(before.nodes, 4, child),
      generated: MapSet.new([4])}
    after_ = %{before | next_id: 6, nodes: Map.put(before.nodes, 5, wrapper),
      generated: MapSet.new([4, 5]), activity: %{5 => 1.0}, edges: %{{4, 5} => 0.1}}

    gated = DevelopmentalMemoryQuality.gate(before, after_,
      recursive_quality_gate: true,
      recursive_min_residual_members: 2,
      minimum_incremental_compression_gain: 1.0)

    refute MapSet.member?(gated.generated, 5)
    refute Map.has_key?(gated.nodes, 5)
  end

  test "quality audit preserves phase retrieval while reducing chain-like wrapping" do
    result = Experiment.run(episodes: 24, probes: 4, seed: 11)
    legacy = Enum.find(result.rows, &(&1.condition == :legacy))
    quality = Enum.find(result.rows, &(&1.condition == :quality))

    assert quality.accuracy >= 0.50
    assert quality.single_child <= legacy.single_child
    assert quality.collapsed_depth <= quality.max_depth
  end
end
