defmodule Procession.Simulation.DevelopmentalFieldTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalField

  test "starts without generated understanding" do
    state = DevelopmentalField.new()

    assert DevelopmentalField.generated_nodes(state) == []
    assert state.edges == %{}
  end

  test "repeated coherent experience consolidates a generated node" do
    inputs = List.duplicate({:body, :unresolved}, 8)
    state = DevelopmentalField.run(inputs, consolidation_threshold: 4)

    assert length(DevelopmentalField.generated_nodes(state)) >= 1
  end

  test "generated structure is reused by similar later experience" do
    training = List.duplicate({:body, :unresolved}, 8)
    state = DevelopmentalField.run(training, consolidation_threshold: 4)
    [node | _] = DevelopmentalField.generated_nodes(state)

    state = DevelopmentalField.step(state, {:body, :unresolved}, consolidation_threshold: 4)
    reused = Map.fetch!(state.nodes, node.id)

    assert reused.reuse > node.reuse
    assert Map.has_key?(state.activity, node.id)
  end

  test "single experiences do not become unique memories" do
    inputs = Enum.map(1..20, &{:novel, &1})
    state = DevelopmentalField.run(inputs, consolidation_threshold: 4)

    assert DevelopmentalField.generated_nodes(state) == []
  end

  test "generated growth remains smaller than experience count" do
    inputs =
      Enum.flat_map(1..12, fn _ ->
        [{:body, :unresolved}, {:body, :resolved}, {:caregiver, :present}]
      end)

    state = DevelopmentalField.run(inputs, consolidation_threshold: 4)

    assert length(DevelopmentalField.generated_nodes(state)) < length(inputs)
  end
end
