defmodule Procession.Simulation.RouteEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle
  alias Procession.Simulation.RouteEvidence

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

  defp setup_world() do
    manager = String.to_atom(unique("evidence_manager"))
    lifecycle = String.to_atom(unique("evidence_lifecycle"))
    travel = String.to_atom(unique("evidence_travel"))
    evidence = String.to_atom(unique("route_evidence"))
    source = unique("source")
    destination = unique("destination")
    alternate = unique("alternate")
    mover = unique("mover")
    partner = unique("partner")

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

    assert {:ok, _} = EntitySupervisor.start_entity(mover, %{name: mover, type: :npc})
    assert {:ok, _} = EntitySupervisor.start_entity(partner, %{name: partner, type: :npc})

    source_region =
      MultiResolutionRegion.new(
        id: source,
        entities: [physical(mover, {0, 0}, 0.2, 0.8), physical(partner, {1, 0}, 0.0)],
        social_relations: %{
          {mover, partner, :presence} => %{confidence: 0.9, persistence: 1.0}
        }
      )

    destination_region = MultiResolutionRegion.new(id: destination, entities: [])
    alternate_region = MultiResolutionRegion.new(id: alternate, entities: [])

    Enum.each([source_region, destination_region, alternate_region], fn region ->
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

          if id in [mover, partner] or state.location in [source, destination, alternate] do
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
      destination: destination,
      alternate: alternate,
      mover: mover
    }
  end

  test "expiring route pressure and resource evidence alter only grounded ticks" do
    world = setup_world()

    assert {:ok, departure} =
             CoarseTravel.depart(
               world.mover,
               world.source,
               world.destination,
               5,
               [travel_demand: 0.01, travel_energy_decay: 0.0],
               world.travel
             )

    assert {:ok, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :storm,
               %{pressure: 2.0, unmet_energy: 0.1},
               1,
               1,
               world.evidence
             )

    assert {:ok, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :forage,
               %{supply: 0.05},
               1,
               1,
               world.evidence
             )

    first = RouteEvidence.advance_travel(1, world.travel, world.evidence)
    assert Enum.any?(first.evidence_events, &match?({:route_effects, _, _}, &1))

    assert {:ok, transit_after_first} =
             LiveResolutionManager.fetch(departure.transit_region, world.manager)

    first_commitment = transit_after_first.summary.identity_commitments[world.mover]
    assert transit_after_first.summary.external_inflow >= 0.05
    assert first_commitment.consumed > 0.01

    second = RouteEvidence.advance_travel(2, world.travel, world.evidence)
    assert second.evidence_events == []

    assert RouteEvidence.route(world.source, world.destination, 2, world.evidence).sources == []
  end

  test "causal obstruction increases physical cost but does not declare the route blocked" do
    world = setup_world()

    assert {:ok, departure} =
             CoarseTravel.depart(
               world.mover,
               world.source,
               world.destination,
               4,
               [travel_energy_decay: 0.0],
               world.travel
             )

    assert {:ok, before_region} =
             LiveResolutionManager.fetch(departure.transit_region, world.manager)

    before = before_region.summary.identity_commitments[world.mover]

    assert {:ok, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :washed_out_bridge,
               %{
                 obstruction: %{
                   cause: :flood_undermined_bridge,
                   severity: 0.9,
                   extent: 0.8,
                   clearance: 0.2
                 }
               },
               1,
               3,
               world.evidence
             )

    result = RouteEvidence.advance_travel(1, world.travel, world.evidence)

    assert {:route_effects, world.mover, details} =
             Enum.find(result.evidence_events, &match?({:route_effects, _, _}, &1))

    assert %{cause: :flood_undermined_bridge, net: net} = hd(details.obstructions)
    assert net > 0.0

    assert {:ok, journey} = CoarseTravel.journey(world.mover, world.travel)
    assert journey.status == :in_transit
    assert journey.elapsed_ticks == 1

    assert {:ok, after_region} =
             LiveResolutionManager.fetch(departure.transit_region, world.manager)

    after_commitment = after_region.summary.identity_commitments[world.mover]
    assert after_commitment.energy < before.energy
    assert after_commitment.consumed > before.consumed
  end

  test "blocked conclusions are rejected in favor of causal obstruction evidence" do
    world = setup_world()

    assert catch_exit(
             RouteEvidence.publish(
               world.source,
               world.destination,
               :closed_road,
               %{blocked: true},
               1,
               2,
               world.evidence
             )
           )
  end

  test "authoritative diversion evidence changes destination without teleportation" do
    world = setup_world()

    assert {:ok, _} =
             CoarseTravel.depart(
               world.mover,
               world.source,
               world.destination,
               6,
               [],
               world.travel
             )

    assert {:ok, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :alternate_route_observed,
               %{divert_to: world.alternate, divert_ticks: 3},
               1,
               1,
               world.evidence
             )

    result = RouteEvidence.advance_travel(1, world.travel, world.evidence)
    assert {:diverted, world.mover, world.alternate, 3} in result.evidence_events

    assert {:ok, journey} = CoarseTravel.journey(world.mover, world.travel)
    assert journey.to == world.alternate
    assert journey.status == :in_transit
    assert journey.elapsed_ticks == 1
    refute journey.status == :arrived
  end
end
