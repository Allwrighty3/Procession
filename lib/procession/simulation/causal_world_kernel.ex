defmodule Procession.Simulation.CausalWorldKernel do
  @moduledoc """
  Deterministic authoritative physical kernel for an active local world.

  The kernel owns positions, obstruction, bodily state, and conserved resource
  quantities. It derives locally available sensory signals and resolves proposed
  physical consequences. Individual mental and motor state remains owned by each
  entity's `LiveSensorimotor` process.

  It does not select named actions, infer goals, or store entity mental geometry.
  """

  defstruct tick: 0,
            bounds: {8, 8},
            perception_radius: 3,
            entities: %{},
            resources: %{},
            obstacles: MapSet.new(),
            events: []

  def new(opts \\ []) do
    entities =
      opts
      |> Keyword.get(:entities, [])
      |> Map.new(fn attrs ->
        id = Map.fetch!(attrs, :id)

        {id,
         %{
           id: id,
           position: Map.get(attrs, :position, {0, 0}),
           energy: Map.get(attrs, :energy, 0.75),
           inventory: Map.get(attrs, :inventory, 0.0)
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
      bounds: Keyword.get(opts, :bounds, {8, 8}),
      perception_radius: Keyword.get(opts, :perception_radius, 3),
      entities: entities,
      resources: resources,
      obstacles: MapSet.new(Keyword.get(opts, :obstacles, []))
    }
  end

  def begin_tick(%__MODULE__{} = world) do
    %{world | tick: world.tick + 1, events: []}
  end

  def entity_ids(%__MODULE__{} = world) do
    world.entities |> Map.keys() |> Enum.sort()
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

    nearby_entity_signals =
      world.entities
      |> Map.values()
      |> Enum.reject(&(&1.id == entity_id))
      |> Enum.sort_by(& &1.id)
      |> Enum.flat_map(fn other ->
        distance = manhattan(entity.position, other.position)

        if distance <= world.perception_radius do
          [
            {:signal,
             {:nearby_body, other.id, relative_direction(entity.position, other.position),
              distance_band(distance)}, proximity_gain(distance)}
          ]
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
      | boundary_signals ++ resource_signals ++ nearby_entity_signals ++ obstacle_signals
    ]
  end

  def resolve(%__MODULE__{} = world, entity_id, outcome, mental_position, opts \\ []) do
    original = Map.fetch!(world.entities, entity_id)
    proposed = physical_proposal(original.position, outcome)
    actual = resolve_position(world, entity_id, original.position, proposed)
    moved? = actual != original.position
    blocked? = actual != proposed or Map.get(outcome, :blocked?, false)

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

    entity = %{contacted | position: actual, energy: energy}

    feedback_features = [
      {:position, actual},
      {:signal, {:body, :energy_pressure}, 1.0 + (1.0 - energy) * 5.0},
      {:signal, {:body, :displacement}, if(moved?, do: 1.0, else: 0.25)},
      {:signal, {:body, :resistance}, if(blocked?, do: 2.0, else: -0.5)}
      | contact_features
    ]

    event = %{
      tick: world.tick,
      entity_id: entity_id,
      motor_pattern: Map.fetch!(outcome, :pattern),
      from: original.position,
      mental_position: mental_position,
      proposed: proposed,
      position: actual,
      displaced?: moved?,
      blocked?: blocked?,
      transferred: intake
    }

    updated =
      world
      |> put_entity(entity)
      |> Map.update!(:events, &[event | &1])

    resolution = %{
      position: actual,
      feedback_features: feedback_features,
      coherence: local_coherence(intake, blocked?),
      event: event
    }

    {updated, resolution}
  end

  def finish_tick(%__MODULE__{} = world) do
    %{world | events: Enum.reverse(world.events)}
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
             inventory: entity.inventory
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

  defp physical_proposal(position, %{displaced?: true, direction: direction}) do
    move(position, direction)
  end

  defp physical_proposal(position, _outcome), do: position

  defp move({x, y}, :north), do: {x, y - 1}
  defp move({x, y}, :south), do: {x, y + 1}
  defp move({x, y}, :east), do: {x + 1, y}
  defp move({x, y}, :west), do: {x - 1, y}
  defp move(position, _direction), do: position

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

  defp relative_direction({x, y}, {other_x, other_y}) do
    dx = other_x - x
    dy = other_y - y

    cond do
      dx == 0 and dy == 0 -> :overlapping
      abs(dx) >= abs(dy) and dx > 0 -> :east
      abs(dx) >= abs(dy) and dx < 0 -> :west
      dy > 0 -> :south
      true -> :north
    end
  end

  defp distance_band(0), do: :contact
  defp distance_band(1), do: :adjacent
  defp distance_band(distance) when distance <= 3, do: :near
  defp distance_band(_distance), do: :far

  defp proximity_gain(distance), do: 1.0 / (max(distance, 0) + 1.0)
  defp manhattan({ax, ay}, {bx, by}), do: abs(ax - bx) + abs(ay - by)
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end