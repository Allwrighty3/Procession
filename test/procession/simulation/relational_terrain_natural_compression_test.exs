defmodule Procession.Simulation.RelationalTerrainNaturalCompressionTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationalTerrainNaturalCompression, as: NaturalCompression

  @opts [
    dimensions: 8,
    deformation_rate: 0.18,
    placement_step: 0.35,
    activity_retention: 0.12,
    flow_fraction: 0.90,
    active_threshold: 0.03,
    auto_expand_dimensions: false,
    reuse_radius: 0.001,
    encoding_salt: :natural_compression_test
  ]

  test "ordinary observations discover practice-dependent assemblies without a supplied route" do
    route = Enum.map(1..64, &{:route, &1})

    lightly_practiced = train(route, 5)
    moderately_practiced = train(route, 20)
    heavily_practiced = train(route, 100)

    assert NaturalCompression.instrumentation(lightly_practiced).maximum_assembly_size == 0
    assert NaturalCompression.instrumentation(moderately_practiced).maximum_assembly_size == 4
    assert NaturalCompression.instrumentation(heavily_practiced).maximum_assembly_size == 16

    assert NaturalCompression.motif_count(heavily_practiced, Enum.take(route, 16)) == 100.0
  end

  test "discovered assemblies compress evaluation without contributing new learning" do
    route = Enum.map(1..64, &{:route, &1})
    state = train(route, 100)
    count_before = NaturalCompression.motif_count(state, Enum.take(route, 16))

    plan = NaturalCompression.compression_plan(state, route)

    assert count_before == NaturalCompression.motif_count(state, Enum.take(route, 16))
    assert plan.transitions_saved >= 48
    assert plan.compression_ratio < 0.25
    assert Enum.all?(plan.assemblies_used, &(&1.size == 16))
  end

  test "a disturbance reopens only assemblies containing the disturbed region" do
    route = Enum.map(1..64, &{:route, &1})
    state = train(route, 100)

    baseline = NaturalCompression.compression_plan(state, route)
    disturbed = NaturalCompression.compression_plan(state, route, disturbances: [Enum.at(route, 20)])

    assert disturbed.transitions_saved < baseline.transitions_saved
    assert disturbed.transitions_saved > 0
    refute Enum.any?(disturbed.assemblies_used, fn assembly -> Enum.at(route, 20) in assembly.members end)
  end

  test "shared repeated structure is discovered across overlapping experiences" do
    shared = Enum.map(1..8, &{:shared, &1})
    left = [{:left, 1}, {:left, 2}] ++ shared ++ [{:left, 3}, {:left, 4}]
    right = [{:right, 1}, {:right, 2}] ++ shared ++ [{:right, 3}, {:right, 4}]

    state =
      Enum.reduce(1..40, NaturalCompression.new(@opts), fn _, acc ->
        acc |> traverse(left) |> NaturalCompression.clear_activity() |> traverse(right) |> NaturalCompression.clear_activity()
      end)

    assert NaturalCompression.motif_count(state, shared) == 80.0
    assert Enum.any?(NaturalCompression.assemblies(state), &(&1.members == shared))
  end

  test "sensorimotor packet members become one order-independent cooccurring experience" do
    first_order = [
      {:sense, :energy, 2},
      {:sense, :vision, 0, 1},
      {:output, 0, 3},
      {:sense, :resistance, 0}
    ]

    second_order = [
      {:output, 0, 3},
      {:sense, :vision, 0, 1},
      {:sense, :energy, 2},
      {:sense, :resistance, 0}
    ]

    state = Enum.reduce(first_order, NaturalCompression.new(@opts), &NaturalCompression.observe(&2, &1, @opts))
    state = Enum.reduce(second_order, state, &NaturalCompression.observe(&2, &1, @opts))
    metrics = NaturalCompression.instrumentation(state)

    assert metrics.trace_window_size == 2
    assert metrics.pending_cooccurrence_members == 0
    assert state.tick == 2
    assert Enum.at(state.trace_window, 0) == Enum.at(state.trace_window, 1)
  end

  test "compression planning normalizes serialized packets into tick transitions" do
    packet = [
      {:sense, :energy, 2},
      {:output, 0, 1},
      {:sense, :resistance, 0}
    ]

    trace = List.duplicate(packet, 10) |> List.flatten()
    state = Enum.reduce(trace, NaturalCompression.new(@opts), &NaturalCompression.observe(&2, &1, @opts))
    plan = NaturalCompression.compression_plan(state, trace)

    assert plan.detailed_transitions == 9
  end

  defp train(route, repetitions) do
    Enum.reduce(1..repetitions, NaturalCompression.new(@opts), fn _, state ->
      state |> traverse(route) |> NaturalCompression.clear_activity()
    end)
  end

  defp traverse(state, route), do: Enum.reduce(route, state, &NaturalCompression.observe(&2, &1, @opts))
end
