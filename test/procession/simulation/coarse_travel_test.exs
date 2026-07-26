defmodule Procession.Simulation.CoarseTravelTest do
  use ExUnit.Case, async: false

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle
  alias Procession.WorldClock

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  defp physical(id, position, inventory, energy \\ 0.75) do
    %{
      id: id,
      position: position,
      energy: energy,
      mobility: 0.8,
      inventory: inventory,
      consumed: 0.0
    }
  end

  defp stop_if_present(id) do
    if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
  end

  defp stop_entities_in(regions, ids) do
    EntitySupervisor.list_entities()
    |> Enum.map(&elem(&1, 0))
    |> Enum.each(fn id ->
      try do
        entity = Entity.get_state(id)

        if id in ids or entity.location in regions do
          stop_if_present(id)
        end
      catch
        :exit, _reason -> :ok
      end
    end)
  end

  defp setup_world() do
    manager = String.to_atom(unique("travel_manager"))
    lifecycle = String.to_atom(unique("travel_lifecycle"))
    travel = String.to_atom(unique("travel_owner"))
    source = unique("source")
    destination = unique("destination")
    alternate = unique("alternate")
    mover = unique("mover")
    partner = unique("partner")
    resident = unique("resident")

    assert {:ok, _pid} = LiveResolutionManager.start_link(name: manager)

    assert {:ok, _pid} =
             RegionActivationLifecycle.start_link(
               name: lifecycle,
               resolution_server: manager
             )

    assert {:ok, _pid} =
             CoarseTravel.start_link(
               name: travel,
               resolution_server: manager,
               lifecycle_server: lifecycle
             )

    Enum.each([mover, partner, resident], fn id ->
      assert {:ok, _pid} = EntitySupervisor.start_entity(id, %{name: id, type: :npc})
    end)

    source_region =
      MultiResolutionRegion.new(
        id: source,
        entities: [
          physical(mover, {1, 1}, 0.12, 0.7),
          physical(partner, {2, 1}, 0.0, 0.8)
        ],
        social_relations: %{
          {mover, partner, :presence} => %{confidence: 0.9, persistence: 1.0}
        }
      )

    destination_region =
      MultiResolutionRegion.new(
        id: destination,
        entities: [physical(resident, {4, 4}, 0.0)]
      )

    alternate_region = MultiResolutionRegion.new(id: alternate, entities: [])

    Enum.each([source_region, destination_region, alternate_region], fn region ->
      assert {:ok, _trace} = LiveResolutionManager.put(region, manager)
      assert {:ok, %{resolution: :inert}} =
               RegionActivationLifecycle.deactivate(region.id, [], lifecycle)
    end)

    on_exit(fn ->
      stop_entities_in([source, destination, alternate], [mover, partner, resident])
    end)

    %{
      manager: manager,
      lifecycle: lifecycle,
      travel: travel,
      source: source,
      destination: destination,
      alternate: alternate,
      mover: mover
    }
  end

  test "dormant identity travels over time, consumes carried stock, and arrives intact" do
    world = setup_world()

    assert {:ok, departure} =
             CoarseTravel.depart(
               world.mover,
               world.source,
               world.destination,
               3,
               [travel_demand: 0.02, route_pressure: 0.5],
               world.travel
             )

    assert departure.status == :in_transit
    assert LiveResolutionManager.dormant_identity_locations(world.manager)[world.mover] ==
             departure.transit_region

    assert %{events: events} = CoarseTravel.advance(2, world.travel)
    refute Enum.any?(events, &match?({:arrived, _, _}, &1))

    assert {:ok, in_transit} = CoarseTravel.journey(world.mover, world.travel)
    assert in_transit.elapsed_ticks == 2
    assert in_transit.status == :in_transit

    assert {:ok, transit} = LiveResolutionManager.fetch(in_transit.transit_region, world.manager)
    commitment = transit.summary.identity_commitments[world.mover]
    assert commitment.inventory < 0.12
    assert commitment.consumed > 0.0
    assert commitment.energy < 0.7
    assert_in_delta commitment.inventory + commitment.consumed, 0.12, 1.0e-9

    assert %{events: final_events} = CoarseTravel.advance(1, world.travel)
    assert {:arrived, world.mover, world.destination} in final_events

    assert {:ok, arrived} = CoarseTravel.journey(world.mover, world.travel)
    assert arrived.status == :arrived
    assert LiveResolutionManager.dormant_identity_locations(world.manager)[world.mover] ==
             world.destination

    assert {:ok, %{resolution: :live}} =
             RegionActivationLifecycle.activate(world.destination, 77, [], world.lifecycle)

    restored = Entity.get_state(world.mover)
    assert restored.location == world.destination
    assert restored.name == world.mover
    assert restored.metadata.physical_state.inventory < 0.12
    assert restored.metadata.physical_state.consumed > 0.0
  end

  test "active journey can divert without teleporting before its new duration completes" do
    world = setup_world()

    assert {:ok, _} =
             CoarseTravel.depart(
               world.mover,
               world.source,
               world.destination,
               5,
               [],
               world.travel
             )

    assert %{events: _} = CoarseTravel.advance(2, world.travel)
    assert {:ok, diverted} = CoarseTravel.divert(world.mover, world.alternate, 2, world.travel)
    assert diverted.to == world.alternate
    assert diverted.elapsed_ticks == 0

    assert %{events: first} = CoarseTravel.advance(1, world.travel)
    refute Enum.any?(first, &match?({:arrived, _, _}, &1))

    assert %{events: second} = CoarseTravel.advance(1, world.travel)
    assert {:arrived, world.mover, world.alternate} in second
    assert LiveResolutionManager.dormant_identity_locations(world.manager)[world.mover] ==
             world.alternate
  end

  test "unmet travel demand can strand a dormant identity in transit" do
    world = setup_world()

    assert {:ok, _} =
             CoarseTravel.depart(
               world.mover,
               world.source,
               world.destination,
               10,
               [
                 travel_demand: 1.0,
                 route_pressure: 4.0,
                 unmet_energy_penalty: 0.5,
                 travel_energy_decay: 0.1,
                 failure_energy: 0.2
               ],
               world.travel
             )

    assert %{events: events} = CoarseTravel.advance(1, world.travel)
    assert {:stranded, world.mover, :exhausted} in events

    assert {:ok, stranded} = CoarseTravel.journey(world.mover, world.travel)
    assert stranded.status == :stranded
    assert LiveResolutionManager.dormant_identity_locations(world.manager)[world.mover] ==
             stranded.transit_region

    assert %{events: later} = CoarseTravel.advance(5, world.travel)
    refute Enum.any?(later, &match?({:arrived, _, _}, &1))

    assert {:ok, recovered} =
             CoarseTravel.divert(world.mover, world.alternate, 2, world.travel)

    assert recovered.status == :in_transit
    assert recovered.to == world.alternate
  end

  test "world clock advances coarse travel before publishing its tick summary" do
    world = setup_world()
    clock = String.to_atom(unique("travel_clock"))

    assert {:ok, _pid} =
             WorldClock.start_link(
               name: clock,
               coarse_travel: true,
               coarse_travel_server: world.travel
             )

    assert {:ok, _} =
             CoarseTravel.depart(
               world.mover,
               world.source,
               world.destination,
               2,
               [],
               world.travel
             )

    assert {:ok, first_tick} = WorldClock.tick(clock)
    assert first_tick.coarse_travel.ticks == 1
    refute Enum.any?(first_tick.coarse_travel.events, &match?({:arrived, _, _}, &1))

    assert {:ok, second_tick} = WorldClock.tick(clock)
    assert {:arrived, world.mover, world.destination} in second_tick.coarse_travel.events
  end
end
