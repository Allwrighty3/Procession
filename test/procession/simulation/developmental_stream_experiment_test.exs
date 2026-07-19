defmodule Procession.Simulation.DevelopmentalStreamExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalStreamExperiment

  test "reports whatever generated structure forms without semantic labels" do
    result = DevelopmentalStreamExperiment.run(ticks: 240, seed: 7)

    assert result.summary.ticks == 240
    assert is_list(result.nodes)

    Enum.each(result.nodes, fn node ->
      assert is_integer(node.id)
      assert node.support_size > 0
      assert node.stability >= 1.0
      assert is_integer(node.reuse)
      assert is_list(node.feature_overlaps)
      assert is_list(node.strongest_edges)
      refute Map.has_key?(node, :meaning)
      refute Map.has_key?(node, :label)
    end)
  end

  test "the same stream produces the same observed geometry" do
    first = DevelopmentalStreamExperiment.run(ticks: 300, seed: 11)
    second = DevelopmentalStreamExperiment.run(ticks: 300, seed: 11)

    assert first.summary == second.summary
    assert first.nodes == second.nodes
  end

  test "generated support remains within the fixed micro-node substrate" do
    result = DevelopmentalStreamExperiment.run(ticks: 360, seed: 3, micro_nodes: 48)

    Enum.each(result.nodes, fn node ->
      assert node.support_size <= 48
    end)
  end
end