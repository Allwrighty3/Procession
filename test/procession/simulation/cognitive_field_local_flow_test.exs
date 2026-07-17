defmodule Procession.Simulation.CognitiveField.LocalFlowTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.LocalFlow

  test "propagation uses only local outgoing transitions and dissipates finite activation" do
    field =
      CognitiveField.new()
      |> CognitiveField.add_transition(:a, :b)
      |> CognitiveField.add_transition(:b, :exit)

    trace = LocalFlow.propagate(field, %{a: 1.0}, exits: [:exit], transfer: 0.5)

    assert trace.status == :settled
    assert trace.exit_activation[:exit] > 0.0
    assert trace.exit_activation[:exit] < 1.0
    assert Enum.any?(trace.flows, &(&1.from == :a and &1.to == :b))
    assert Enum.any?(trace.flows, &(&1.from == :b and &1.to == :exit))
  end

  test "simultaneous entries combine at a shared node" do
    field =
      CognitiveField.new()
      |> CognitiveField.add_transition(:a, :shared)
      |> CognitiveField.add_transition(:b, :shared)
      |> CognitiveField.add_transition(:shared, :exit)

    alone = LocalFlow.propagate(field, %{a: 0.5}, exits: [:exit])
    together = LocalFlow.propagate(field, %{a: 0.5, b: 0.5}, exits: [:exit])

    assert together.exit_activation[:exit] > alone.exit_activation[:exit]
  end

  test "developed fragments support a complete route that was never trained" do
    base =
      CognitiveField.new()
      |> CognitiveField.add_transition(:a, :m)
      |> CognitiveField.add_transition(:m, :x)
      |> CognitiveField.add_transition(:b, :n)
      |> CognitiveField.add_transition(:n, :y)
      |> CognitiveField.add_transition(:m, :bridge)
      |> CognitiveField.add_transition(:bridge, :n)

    trained =
      Enum.reduce(1..35, base, fn _, acc ->
        acc
        |> CognitiveField.traverse([:a, :m, :x])
        |> CognitiveField.traverse([:b, :n, :y])
      end)
      |> CognitiveField.add_transition(:m, :bridge, residue: 0.95)
      |> CognitiveField.add_transition(:bridge, :n, residue: 0.95)

    trace =
      LocalFlow.propagate(
        trained,
        %{a: 0.8, b: 0.25},
        exits: [:x, :y],
        transfer: 0.95,
        temperature: 0.18,
        threshold: 0.001
      )

    trained_paths = [[:a, :m, :x], [:b, :n, :y], [:m, :bridge, :n]]

    assert trace.exit_activation[:x] > 0.0
    assert trace.exit_activation[:y] > 0.0
    assert LocalFlow.novel_complete_path?(trace, trained_paths)
    assert Enum.any?(trace.flows, &(&1.from == :m and &1.to == :bridge))
    assert Enum.any?(trace.flows, &(&1.from == :bridge and &1.to == :n))
  end

  test "combined activation makes a recombined exit more reachable than either weak cue alone" do
    field =
      CognitiveField.new()
      |> CognitiveField.add_transition(:a, :join, residue: 0.7)
      |> CognitiveField.add_transition(:b, :join, residue: 0.7)
      |> CognitiveField.add_transition(:join, :exit, residue: 0.7)

    a = LocalFlow.propagate(field, %{a: 0.06}, exits: [:exit], threshold: 0.05)
    b = LocalFlow.propagate(field, %{b: 0.06}, exits: [:exit], threshold: 0.05)
    both = LocalFlow.propagate(field, %{a: 0.06, b: 0.06}, exits: [:exit], threshold: 0.05)

    assert Map.get(a.exit_activation, :exit, 0.0) == 0.0
    assert Map.get(b.exit_activation, :exit, 0.0) == 0.0
    assert both.exit_activation[:exit] > 0.0
  end
end
