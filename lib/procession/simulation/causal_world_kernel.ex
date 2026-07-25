defmodule Procession.Simulation.CausalWorldKernel do
  @moduledoc """
  Deterministic authoritative physical kernel for an active local world.

  The kernel owns positions, obstruction, bodily state, and conserved resource
  quantities. Entity mental planes receive only locally derived signals and emit
  opaque motor-channel patterns. The kernel resolves the resulting displacement,
  contact, and transfer before returning locally sensed consequences to the plane.

  It does not select named actions, infer goals, or write desired outcomes into an
  entity's mental state.
  """

  alias Procession.Simulation.DevelopmentalSensorimotorLoop

  defstruct tick: 0,
            bounds: {8, 8},
            perception_radius: 3,
            entities: %{},
            resources: %{},
            obstacles: MapSet.new(),
            events: []

  def new(opts \\ []) do
    bounds = Keyword.get(opts, :bounds, {8, 8})
    radius = Keyword.get(opts, :perception_radius, 3)

    entities =
      opts
      |> Keyword.get(:entities, [])
      |> Map.new(fn attrs ->
        id = Map.fetch!(attrs, :id)
        position = Map.get(attrs, :position, {0, 0})

        loop_opts =
          attrs
          |> Map.get(:loop_opts, [])
          |> Keyword.put_new(:position, position)
          |> Keyword.put_new(:bounds, bounds)

        {id,
         %{
           id: id,
           position: position,
           energy: Map.get(attrs, :energy, 0.75),
           inventory: Map.get(attrs, :inventory, 0.0),
           loop: DevelopmentalSensorimotorLoop.new(loop_opts)
         }}
      end)

    resources =
      opts
      |> Keyword.get(:resources, [])
      |> Map.new(fn attrs ->
        id = Map.fetch!(attrs, :id)

        {id,
         %{
           id: id,
           position: Map.fetch!(attrs, :position),
           quantity: max(0.0, Map.get(attrs, :quantity, 1.0)),
           signal_strength: max(0.0, Map.get(attrs, :signal_strength, 1.0))
         }}
      end)

    %__MODULE__{
      bounds: bounds,
      perception_radius: radius,
      entities: entities,
      resources: resources,
      obstacles: MapSet.new(Keyword.get(opts, :obstacles, []))
    }
  end

  def tick(%__MODULE__{} = world, opts \\ []) do
    tick = world.tick + 1

    world =
      world.entities
      |> Map.keys()
      |> Enum.sort()
      |> Enum.reduce(%{world | tick: tick, events: []}, fn entity_id, state ->
        step_entity(state, entity_id, opts)
      end)

    %{world | events: Enum.reverse(world.events)}
  end

  def run(world, ticks, opts \\ [])

  def run(%__MODULE__{} = world, 0, _opts), do: world

  def run(%__MODULE__{} = world, ticks, opts) when is_integer(ticks) and ticks > 0 do
    Enum.reduce(1..ticks, world, fn _, state -> tick(state, opts) end)
  end

  def perceive(%__MODULE__{} = world, entity_id) do
    entity = Map.fetch!(world.entities, entity_id)
    {x, y} = entity.position
    {max_x, max_y} = world.bounds

    boundary_signals = [
      {:signal, {:boundary, :west}, proximity_gain(x)},
      {:signal, {:boundary, :north}, proximity_gain(y)},
      {:signal, {:boundary, :east}, proximity_gain(max_x - x)},
      {:signal, {:boundary, :south}, proximity_gain(max_y - y)}
    ]

    resource_signals =
      world.resources
      |> Map.values()
      |> Enum.filter(&(&1.quantity > 0.0))
      |> Enum.flat_map(fn resource ->
        distance = manhattan(entity.position, resource.position)

        if distance <= world.perception_radius do
          magnitude =
            resource.signal_strength *
              (world.perception_radius - distance + 1) / (world.perception_radius + 1)

          [{:signal, {:resource_presence, resource.id}, magnitude}]
        else
          []
        end
      end)

    obstacle_signals =
      entity.position
      |> adjacent_positions()
      |> Enum.flat_map(fn {direction, position} ->
        if blocked_position?(world, position) do
          [{:signal, {:resistance, direction}, 1.5}]
        else
          []
        end
      end)

    hunger = max(0.0, 1.0 - entity.energy)

    [
      {:signal, {:body, :energy_pressure}, 1.0 + hunger * 5.0},
      {:position, entity.position}
      | boundary_signals ++ resource_signals ++ obstacle_signals
    ]
  end

  def trace(%__MODULE__{} = world) do
    %{
      tick: world.tick,
      entities:
        Map.new(world.entities, fn {id, entity} ->
          {id,
           %{
             position: entity.position,
             energy: entity.energy,
             inventory: entity.inventory,
             sensorimotor: DevelopmentalSensorimotorLoop.trace(entity.loop)
           }}
        end),
      resources: Map.new(world.resources, fn {id, resource} -> {id, resource.quantity} end),
      events: world.events
    }
  end

  def total_resource(%__MODULE__{} = world) do
    loose = world.resources |> Map.values() |> Enum.map(& &1.quantity) |> Enum.sum()
    held = world.entities |> Map.values() |> Enum.map(& &1.inventory) |> Enum.sum()
    loose + held
  end

  defp step_entity(world, entity_id, opts) do
    original = Map.fetch!(world.entities, entity_id)
    features = perceive(world, entity_id)
    effective_opts = Keyword.put_new(opts, :bounds, world.bounds)
    sensed = DevelopmentalSensorimotorLoop.sense(original.loop, features, effective_opts)
    {emitted, outcome} = DevelopmentalSensorimotorLoop.emit(sensed, world.tick, effective_opts)

    proposed = emitted.position
    actual = resolve_position(world, entity_id, original.position, proposed)
    moved? = actual != original.position
    blocked? = actual != proposed or outcome.blocked?
    emitted = %{emitted | position: actual}

    {world, contacted, contact_features, intake} =
      world
      |> put_entity(%{original | position: actual})
      |> transfer_contact_resource(entity_id, opts)

    movement_cost = if moved?, do: 0.006, else: 0.0025

    energy =
      contacted.energy
      |> Kernel.-(movement_cost)
      |> Kernel.+(intake)
      |> clamp(0.0, 1.0)

    consequence_features = [
      {:position, actual},
      {:signal, {:body, :energy_pressure}, 1.0 + (1.0 - energy) * 5.0},
      {:signal, {:body, :displacement}, if(moved?, do: 1.0, else: 0.25)},
      {:signal, {:body, :resistance}, if(blocked?, do: 2.0, else: -0.5)}
      | contact_features
    ]

    loop =
      DevelopmentalSensorimotorLoop.feedback(
        emitted,
        consequence_features,
        local_coherence(intake, blocked?),
        effective_opts
      )

    entity = %{contacted | position: actual, energy: energy, loop: loop}

    event = %{
      tick: world.tick,
      entity_id: entity_id,
      motor_pattern: outcome.pattern,
      from: original.position,
      proposed: proposed,
      position: actual,
      displaced?: moved?,
      blocked?: blocked?,
      transferred: intake
    }

    world
    |> put_entity(entity)
    |> Map.update!(:events, &[event | &1])
  end

  defp transfer_contact_resource(world, entity_id, opts) do
    entity = Map.fetch!(world.entities, entity_id)
    intake_limit = Keyword.get(opts, :contact_transfer_limit, 0.12)

    case world.resources
         |> Map.values()
         |> Enum.filter(&(&1.position == entity.position and &1.quantity > 0.0))
         |> Enum.sort_by(& &1.id)
         |> List.first() do
      nil ->
        {world, entity, [], 0.0}

      resource ->
        amount = min(resource.quantity, intake_limit)
        resource = %{resource | quantity: resource.quantity - amount}
        entity = %{entity | inventory: entity.inventory + amount}

        world =
          world
          |> put_in([Access.key(:resources), resource.id], resource)
          |> put_entity(entity)

        {world, entity, [{:signal, {:contact, :resource, resource.id}, 1.0 + amount * 5.0}],
         amount}
    end
  end

  defp resolve_position(world, entity_id, old_position, proposed) do
    occupied? =
      Enum.any?(world.entities, fn {other_id, entity} ->
        other_id != entity_id and entity.position == proposed
      end)

    if proposed == old_position or blocked_position?(world, proposed) or occupied? do
      old_position
    else
      proposed
    end
  end

  defp blocked_position?(world, {x, y} = position) do
    {max_x, max_y} = world.bounds
    x < 0 or y < 0 or x > max_x or y > max_y or MapSet.member?(world.obstacles, position)
  end

  defp local_coherence(intake, blocked?) do
    cond do
      intake > 0.0 -> min(1.0, intake * 4.0)
      blocked? -> -0.2
      true -> 0.0
    end
  end

  defp put_entity(world, entity), do: put_in(world.entities[entity.id], entity)

  defp adjacent_positions({x, y}) do
    [north: {x, y - 1}, south: {x, y + 1}, east: {x + 1, y}, west: {x - 1, y}]
  end

  defp proximity_gain(distance), do: 1.0 / (max(distance, 0) + 1.0)
  defp manhattan({ax, ay}, {bx, by}), do: abs(ax - bx) + abs(ay - by)
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
