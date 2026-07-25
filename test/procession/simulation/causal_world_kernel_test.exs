defmodule Procession.Simulation.CausalWorldKernelTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CausalWorldKernel

  defp world(opts \\ []) do
    defaults = [
      bounds: {6, 6},
      perception_radius: 2,
      entities: [
        %{
          id: "mara",
          position: {2, 2},
          energy: 0.35,
          loop_opts: [
            field_opts: [micro_nodes: 96, input_width: 4, encoding_salt: :causal_world_test],
            body_opts: [initial_coordination: 1.0]
          ]
        }
      ],
      resources: [
        %{id: "near_food", position: {2, 2}, quantity: 1.0, signal_strength: 2.0},
        %{id: "far_food", position: {6, 6}, quantity: 1.0, signal_strength: 2.0}
      ]
    ]

    CausalWorldKernel.new(Keyword.merge(defaults, opts))
  end

  test "perception is local and magnitude is grounded in distance" do
    world = world()
    signals = CausalWorldKernel.perceive(world, "mara")

    assert {:signal, {:resource_presence, "near_food"}, 2.0} in signals

    refute Enum.any?(signals, fn
             {:signal, {:resource_presence, "far_food"}, _magnitude} -> true
             _ -> false
           end)

    assert {:signal, {:body, :energy_pressure}, 4.25} in signals
  end

  test "contact transfers a conserved quantity and returns the consequence to the plane" do
    initial =
      world(
        obstacles: [{2, 1}, {2, 3}, {1, 2}, {3, 2}],
        resources: [%{id: "food", position: {2, 2}, quantity: 0.5, signal_strength: 1.0}]
      )

    total = CausalWorldKernel.total_resource(initial)
    updated = CausalWorldKernel.run(initial, 3, contact_transfer_limit: 0.1)

    assert_in_delta CausalWorldKernel.total_resource(updated), total, 1.0e-9
    assert_in_delta updated.entities["mara"].inventory, 0.3, 1.0e-9
    assert_in_delta updated.resources["food"].quantity, 0.2, 1.0e-9
    assert updated.entities["mara"].energy > initial.entities["mara"].energy
    assert updated.entities["mara"].loop.cycles == 3
    assert updated.entities["mara"].loop.pending_output == nil
  end

  test "authoritative obstruction prevents the mental body's proposed position from becoming world truth" do
    initial = world(obstacles: [{2, 1}, {2, 3}, {1, 2}, {3, 2}], resources: [])
    updated = CausalWorldKernel.run(initial, 20)

    assert updated.entities["mara"].position == {2, 2}
    assert Enum.any?(updated.events, & &1.blocked?)
    assert updated.entities["mara"].loop.position == {2, 2}
  end

  test "world events expose opaque motor patterns rather than named actions" do
    updated = world(resources: []) |> CausalWorldKernel.tick()
    [event] = updated.events

    assert match?({channel_a, channel_b} when is_atom(channel_a) and is_atom(channel_b), event.motor_pattern)
    refute Map.has_key?(event, :action)
    refute Map.has_key?(event, :goal)
    refute Map.has_key?(event, :correct_output)
  end

  test "the same initial state and seed produce the same causal trace" do
    left = world(resources: []) |> CausalWorldKernel.run(25, seed: 77)
    right = world(resources: []) |> CausalWorldKernel.run(25, seed: 77)

    assert CausalWorldKernel.trace(left) == CausalWorldKernel.trace(right)
  end

  test "zero ticks preserve the exact world" do
    initial = world()
    assert CausalWorldKernel.run(initial, 0) == initial
  end
end
