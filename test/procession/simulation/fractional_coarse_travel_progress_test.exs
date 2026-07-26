defmodule Procession.Simulation.FractionalCoarseTravelProgressTest do
  use ExUnit.Case, async: false

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle
  alias Procession.Simulation.RouteEvidence

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  defp physical(id, position, mobility, energy) do
    %{
      id: id,
      position: position,
      energy: energy,
      mobility: mobility,
      inventory: 1.0,
      consumed: 0.0
    }
  end

  defp setup_world(travelers) do
    manager = String.to_atom(unique("progress_manager"))
    lifecycle = String.to_atom(unique("progress_lifecycle"))
    travel = String.to_atom(unique("progress_travel"))
    evidence = String.to_atom(unique("progress_evidence"))
    source = unique("source")
    destination = unique("destination")

    assert {:ok, _} = LiveResolutionManager.start_link(name: manager)

    assert {:ok, _} =
             RegionActivationLifecycle.start_link(
               name: lifecycle,
               resolution_server: manager
             )

    assert {:ok, _} =
             CoarseTravel.start_link(
               name: travel,
               resolution_server: manager,
               lifecycle_server: lifecycle
             )

    assert {:ok, _} = RouteEvidence.start_link(name: evidence, resolution_server: manager)

    Enum.each(travelers, fn {id, _mobility, _energy} ->
      assert {:ok, _} = EntitySupervisor.start_entity(id, %{name: id, type: :npc})
    end)

    entities =
      travelers
      |> Enum.with_index()
      |> Enum.map(fn {{id, mobility, energy}, index} ->
        physical(id, {index, 0}, mobility, energy)
      end)

    source_region = MultiResolutionRegion.new(id: source, entities: entities)
    destination_region = MultiResolutionRegion.new(id: destination, entities: [])

    Enum.each([source_region, destination_region], fn region ->
      assert {:ok, _} = LiveResolutionManager.put(region, manager)
      assert {:ok, %{resolution: :inert}} =
               RegionActivationLifecycle.deactivate(region.id, [], lifecycle)
    end)

    on_exit(fn ->
      EntitySupervisor.list_entities()
      |> Enum.map(&elem(&1, 0))
      |> Enum.each(fn id ->
        try do
          state = Entity.get_state(id)

          if Enum.any?(travelers, fn {traveler_id, _, _} -> traveler_id == id end) or
               state.location in [source, destination] do
            EntitySupervisor.stop_entity(id)
          end
        catch
          :exit, _ -> :ok
        end
      end)
    end)

    %{
      manager: manager,
      lifecycle: lifecycle,
      travel: travel,
      evidence: evidence,
      source: source,
      destination: destination
    }
  end

  test "elapsed time advances while one-tick resistance reduces only achieved progress" do
    mover = unique("mover")
    world = setup_world([{mover, 0.8, 0.8}])

    assert {:ok, departure} =
             CoarseTravel.depart(mover, world.source, world.destination, 2, [], world.travel)

    assert departure.progress == 0.0
    assert departure.required_progress == 2.0

    assert {:ok, _} = CoarseTravel.set_progress_factor(mover, 0.25, world.travel)
    CoarseTravel.advance(1, world.travel)

    assert {:ok, first} = CoarseTravel.journey(mover, world.travel)
    assert first.elapsed_ticks == 1
    assert_in_delta first.progress, 0.25, 1.0e-9
    assert first.status == :in_transit

    CoarseTravel.advance(1, world.travel)

    assert {:ok, second} = CoarseTravel.journey(mover, world.travel)
    assert second.elapsed_ticks == 2
    assert_in_delta second.progress, 1.25, 1.0e-9
    assert second.status == :in_transit

    CoarseTravel.advance(1, world.travel)

    assert {:ok, arrived} = CoarseTravel.journey(mover, world.travel)
    assert arrived.elapsed_ticks == 3
    assert arrived.progress >= arrived.required_progress
    assert arrived.status == :arrived
  end

  test "the same physical condition yields traveler-relative progress without changing stored evidence" do
    capable = unique("capable")
    depleted = unique("depleted")
    world = setup_world([{capable, 0.95, 0.95}, {depleted, 0.15, 0.15}])

    Enum.each([capable, depleted], fn id ->
      assert {:ok, _} =
               CoarseTravel.depart(id, world.source, world.destination, 5, [], world.travel)
    end)

    condition = %{
      cause: :flood_deposited_timber,
      affected_extent: 0.9,
      material_resistance: 0.9,
      surface_instability: 0.8,
      displacement: 0.7,
      visibility_loss: 0.2,
      environmental_intensity: 0.6
    }

    assert {:ok, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :flood_aftermath,
               %{conditions: [condition]},
               1,
               1,
               world.evidence
             )

    result = RouteEvidence.advance_travel(1, world.travel, world.evidence)
    assert length(result.evidence_events) == 2

    assert {:ok, capable_journey} = CoarseTravel.journey(capable, world.travel)
    assert {:ok, depleted_journey} = CoarseTravel.journey(depleted, world.travel)

    assert capable_journey.elapsed_ticks == 1
    assert depleted_journey.elapsed_ticks == 1
    assert capable_journey.progress < 1.0
    assert depleted_journey.progress < capable_journey.progress
    assert capable_journey.status == :in_transit
    assert depleted_journey.status == :in_transit

    stored = RouteEvidence.route(world.source, world.destination, 1, world.evidence)
    assert stored.conditions == [condition]
    refute Map.has_key?(hd(stored.conditions), :difficulty)
    refute Map.has_key?(hd(stored.conditions), :passability)
    refute Map.has_key?(hd(stored.conditions), :experienced_resistance)
  end
end
