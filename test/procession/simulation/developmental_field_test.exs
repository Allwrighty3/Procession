defmodule Procession.Simulation.DevelopmentalFieldTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalField

  test "starts without generated understanding" do
    state = DevelopmentalField.new()
    assert DevelopmentalField.generated_nodes(state) == []
    assert state.edges == %{}
  end

  test "repeated coherent experience consolidates a generated node" do
    state = DevelopmentalField.run(List.duplicate({:body, :unresolved}, 8), consolidation_threshold: 4)
    assert length(DevelopmentalField.generated_nodes(state)) >= 1
  end

  test "compression gain amortizes model cost across recurrence" do
    support = MapSet.new([1, 2])
    early = DevelopmentalField.compression_gain(support, 4)
    repeated = DevelopmentalField.compression_gain(support, 10)

    assert early.gain < 0.0
    assert repeated.gain >= 2.0
    assert repeated.direct_cost > repeated.compressed_cost
  end

  test "generated nodes record positive compression gain" do
    state = DevelopmentalField.run(List.duplicate({:body, :unresolved}, 10), consolidation_threshold: 4)

    assert Enum.all?(DevelopmentalField.generated_nodes(state), fn node ->
             node.compression_gain >= 2.0 and node.direct_cost > node.compressed_cost
           end)
  end

  test "generated structure is reused before later plasticity" do
    opts = [consolidation_threshold: 4]
    state = DevelopmentalField.run(List.duplicate({:body, :unresolved}, 8), opts)
    [node | _] = DevelopmentalField.generated_nodes(state)

    state = DevelopmentalField.step(state, {:body, :unresolved}, opts)
    reused = Map.fetch!(state.nodes, node.id)

    assert reused.reuse > node.reuse
    assert Map.has_key?(state.activity, node.id)
    assert Enum.any?(state.edges, fn {{source, target}, _weight} ->
             source == node.id or target == node.id
           end)
  end

  test "familiar generated structure compresses learning but preserves raw activity" do
    opts = [
      micro_nodes: 96,
      input_width: 3,
      consolidation_threshold: 3,
      minimum_compression_gain: -100.0,
      coherence_threshold: 0.0,
      reuse_threshold: 0.5,
      compression_coverage_threshold: 0.5,
      compression_support_attenuation: 0.01
    ]

    state = DevelopmentalField.run(List.duplicate(:familiar_pattern, 7), opts)
    [node | _] = DevelopmentalField.generated_nodes(state)
    state = DevelopmentalField.step(state, :familiar_pattern, opts)
    snapshot = hd(state.history)

    assert snapshot.explained_nodes > 0
    assert snapshot.learning_field < snapshot.active_field
    assert Map.get(state.activity, node.id, 0.0) > 0.0
    assert Enum.all?(node.support, &(Map.get(state.activity, &1, 0.0) >= 0.18))
  end

  test "single experiences do not become unique memories" do
    state = DevelopmentalField.run(Enum.map(1..20, &{:novel, &1}), consolidation_threshold: 4)
    assert DevelopmentalField.generated_nodes(state) == []
  end

  test "generated growth remains smaller than experience count" do
    inputs = Enum.flat_map(1..12, fn _ ->
      [{:body, :unresolved}, {:body, :resolved}, {:caregiver, :present}]
    end)

    state = DevelopmentalField.run(inputs, consolidation_threshold: 4)
    assert length(DevelopmentalField.generated_nodes(state)) < length(inputs)
  end

  test "temporal plasticity stores direction instead of canonicalizing an edge" do
    opts = [
      micro_nodes: 128,
      input_width: 1,
      coactive_evidence_weight: 0.0,
      temporal_evidence_weight: 2.0,
      plasticity_budget: 0.5,
      plasticity_fanout: 4,
      activity_retention: 0.8,
      consolidation_threshold: 99
    ]

    state = DevelopmentalField.new(opts)
    [a] = DevelopmentalField.active_micro_nodes(state, :a, opts) |> MapSet.to_list()
    [b] = DevelopmentalField.active_micro_nodes(state, :b, opts) |> MapSet.to_list()
    refute a == b

    state = state |> DevelopmentalField.step(:a, opts) |> DevelopmentalField.step(:b, opts)

    assert Map.get(state.edges, {a, b}, 0.0) > Map.get(state.edges, {b, a}, 0.0)
  end

  test "generated nodes can become support for later generated structure" do
    opts = [
      micro_nodes: 96,
      input_width: 2,
      consolidation_threshold: 3,
      minimum_compression_gain: -100.0,
      coherence_threshold: 0.0,
      reuse_threshold: 0.5,
      activity_retention: 0.55,
      plasticity_threshold: 0.15
    ]

    state = DevelopmentalField.run(List.duplicate(:a, 8), opts)
    first_ids = state.generated
    assert MapSet.size(first_ids) >= 1

    state = Enum.reduce(List.duplicate(:b, 8), state, &DevelopmentalField.step(&2, &1, opts))
    state = Enum.reduce(List.duplicate({:features, [:a, :b]}, 12), state, &DevelopmentalField.step(&2, &1, opts))

    assert Enum.any?(DevelopmentalField.generated_nodes(state), fn node ->
             not MapSet.disjoint?(node.support, first_ids)
           end)

    assert Enum.any?(state.edges, fn {{source, target}, _weight} ->
             MapSet.member?(state.generated, source) and MapSet.member?(state.generated, target)
           end)
  end
end