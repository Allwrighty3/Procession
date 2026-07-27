defmodule Procession.Simulation.CausalWorldKernelTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CausalWorldKernel

  defp world(opts \\ []) do
    defaults = [
      bounds: {6, 6},
      perception_radius: 2,
      entities: [%{id: "mara", position: {2, 2}, energy: 0.35}],
      resources: [
        %{id: "near_food", position: {2, 2}, quantity: 1.0, signal_strength: 2.0},
        %{id: "far_food", position: {6, 6}, quantity: 1.0, signal_strength: 2.0}
      ]
    ]

    CausalWorldKernel.new(Keyword.merge(defaults, opts))
  end

  defp outcome(overrides \\ %{}) do
    Map.merge(
      %{
        pattern: {:m1, :m2},
        blocked?: false,
        displaced?: true,
        direction: :north,
        consequence: :displacement
      },
      overrides
    )
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

  test "nearby bodies are perceived by relative direction and grounded distance" do
    world =
      world(
        perception_radius: 3,
        entities: [
          %{id: "mara", position: {2, 2}, energy: 0.5},
          %{id: "oren", position: {3, 2}, energy: 0.5},
          %{id: "sela", position: {2, 4}, energy: 0.5}
        ],
        resources: []
      )

    signals = CausalWorldKernel.perceive(world, "mara")

    assert {:signal, {:nearby_body, "oren", :east, :adjacent}, 0.5} in signals
    assert {:signal, {:nearby_body, "sela", :south, :near}, 1.0 / 3.0} in signals
  end

  test "bodies outside perception radius do not leak into sensory input" do
    world =
      world(
        perception_radius: 1,
        entities: [
          %{id: "mara", position: {0, 0}, energy: 0.5},
          %{id: "oren", position: {2, 0}, energy: 0.5}
        ],
        resources: []
      )

    refute Enum.any?(CausalWorldKernel.perceive(world, "mara"), fn
             {:signal, {:nearby_body, "oren", _direction, _distance}, _magnitude} -> true
             _ -> false
           end)
  end

  test "contact transfers a conserved quantity and produces grounded feedback" do
    initial =
      world(
        obstacles: [{2, 1}, {2, 3}, {1, 2}, {3, 2}],
        resources: [%{id: "food", position: {2, 2}, quantity: 0.5, signal_strength: 1.0}]
      )
      |> CausalWorldKernel.begin_tick()

    total = CausalWorldKernel.total_resource(initial)

    {updated, resolution} =
      CausalWorldKernel.resolve(
        initial,
        "mara",
        outcome(),
        {2, 1},
        contact_transfer_limit: 0.1
      )

    assert_in_delta CausalWorldKernel.total_resource(updated), total, 1.0e-9
    assert_in_delta updated.entities["mara"].inventory, 0.1, 1.0e-9
    assert_in_delta updated.resources["food"].quantity, 0.4, 1.0e-9
    assert updated.entities["mara"].energy > initial.entities["mara"].energy
    assert resolution.position == {2, 2}
    assert {:signal, {:contact, :resource, "food"}, 1.5} in resolution.feedback_features
  end

  test "authoritative obstruction overrides a proposed position" do
    initial =
      world(obstacles: [{2, 1}], resources: [])
      |> CausalWorldKernel.begin_tick()

    {updated, resolution} =
      CausalWorldKernel.resolve(initial, "mara", outcome(), {2, 1})

    assert updated.entities["mara"].position == {2, 2}
    assert resolution.position == {2, 2}
    assert resolution.event.blocked?
  end

  test "occupancy prevents two entities from sharing one position" do
    initial =
      world(
        entities: [
          %{id: "mara", position: {2, 2}, energy: 0.5},
          %{id: "oren", position: {2, 1}, energy: 0.5}
        ],
        resources: []
      )
      |> CausalWorldKernel.begin_tick()

    {updated, resolution} =
      CausalWorldKernel.resolve(initial, "mara", outcome(), {2, 1})

    assert updated.entities["mara"].position == {2, 2}
    assert resolution.event.blocked?
  end

  test "a desynchronized mental coordinate cannot teleport the physical body" do
    initial = world(resources: []) |> CausalWorldKernel.begin_tick()

    {updated, resolution} =
      CausalWorldKernel.resolve(initial, "mara", outcome(%{direction: :east}), {99, 99})

    assert updated.entities["mara"].position == {3, 2}
    assert resolution.event.proposed == {3, 2}
    assert resolution.event.mental_position == {99, 99}
  end

  test "world events expose opaque motor patterns rather than named actions" do
    initial = world(resources: []) |> CausalWorldKernel.begin_tick()
    {updated, _resolution} = CausalWorldKernel.resolve(initial, "mara", outcome(), {2, 1})
    [event] = CausalWorldKernel.finish_tick(updated).events

    assert match?(
             {channel_a, channel_b} when is_atom(channel_a) and is_atom(channel_b),
             event.motor_pattern
           )

    refute Map.has_key?(event, :action)
    refute Map.has_key?(event, :goal)
    refute Map.has_key?(event, :correct_output)
  end

  test "the physical kernel contains no entity mental geometry" do
    initial = world()

    refute Map.has_key?(initial.entities["mara"], :loop)
    refute Map.has_key?(initial.entities["mara"], :sensorimotor)
  end

  test "the same physical proposal produces the same authoritative result" do
    left = world(resources: []) |> CausalWorldKernel.begin_tick()
    right = world(resources: []) |> CausalWorldKernel.begin_tick()

    {left, _} = CausalWorldKernel.resolve(left, "mara", outcome(), {2, 1})
    {right, _} = CausalWorldKernel.resolve(right, "mara", outcome(), {2, 1})

    assert CausalWorldKernel.trace(left) == CausalWorldKernel.trace(right)
  end
end