defmodule Procession.Simulation.RouteEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.EntitySupervisor
  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle
  alias Procession.Simulation.RouteEvidence

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  defp physical(id, position, inventory, energy) do
    %{id: id, position: position, inventory: inventory, consumed: 0.0, energy: energy, mobility: 1.0}
  end

  test "route evidence aggregates bounded effects and expires" do
    server = String.to_atom(unique("route_evidence"))
    assert {:ok, _pid} = RouteEvidence.start_link(name: server)

    assert {:ok, _} =
             RouteEvidence.publish(:a, :b, %{demand_pressure: 3.0, movement_resistance: 0.4}, 10,
               [ttl_ticks: 2, source: :weather],
               server
             )

    assert {:ok, _} =
             RouteEvidence.publish(:a, :b, %{demand_pressure: 3.0, support: 0.3}, 10,
               [ttl_ticks: 1, source: :companions],
               server
             )

    active = RouteEvidence.effective(:a, :b, 11, server)
    assert active.demand_pressure == 4.0
    assert active.movement_resistance == 0.4
    assert active.support == 0.3
    assert active.evidence_count == 2

    later = RouteEvidence.effective(:a, :b, 12, server)
    assert later.evidence_count == 1
    assert later.support == 0.0

    expired = RouteEvidence.effective(:a, :b, 13, server)
    assert expired.evidence_count == 0
    assert expired.demand_pressure == 0.0
  end

  test "grounded resistance delays progress while pressure still changes the body" do
    evidence = String.to_atom(unique("route_evidence"))
    travel = String.to_atom(unique("coarse_travel"))
    source = unique("source")
    destination = unique("destination")
    mover = unique("mover")
    partner = unique("partner")
    resident = unique("resident")

    assert {:ok, _pid} = RouteEvidence.start_link(name: evidence)
    assert {:ok, _pid} = CoarseTravel.start_link(name: travel, evidence_server: evidence)

    Enum.each([mover, partner, resident], fn id ->
      assert {:ok, _pid} = EntitySupervisor.start_entity(id, %{name: id, type: :npc})
    end)

    on_exit(fn ->
      Enum.each([mover, partner, resident], fn id ->
        if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
      end)
    end)

    source_region =
      MultiResolutionRegion.new(
        id: source,
        entities: [physical(mover, {0, 0}, 0.02, 0.8), physical(partner, {1, 0}, 0.0, 0.8)],
        social_relations: %{
          {mover, partner, :presence} => %{confidence: 0.9, persistence: 1.0}
        }
      )

    destination_region =
      MultiResolutionRegion.new(
        id: destination,
        entities: [physical(resident, {2, 0}, 0.0, 0.8)]
      )

    assert {:ok, _} = LiveResolutionManager.put(source_region)
    assert {:ok, _} = LiveResolutionManager.put(destination_region)
    assert {:ok, _} = RegionActivationLifecycle.deactivate(source)
    assert {:ok, _} = RegionActivationLifecycle.deactivate(destination)

    assert {:ok, _} =
             RouteEvidence.publish(
               source,
               destination,
               %{movement_resistance: 1.0, demand_pressure: 2.0, energy_pressure: 2.0},
               0,
               [ttl_ticks: 1, source: :physical_route],
               evidence
             )

    assert {:ok, departure} =
             CoarseTravel.depart(
               mover,
               source,
               destination,
               2,
               [travel_demand: 0.02, unmet_energy_penalty: 0.1],
               travel
             )

    assert %{events: _} = CoarseTravel.advance(1, travel)
    assert {:ok, delayed} = CoarseTravel.journey(mover, travel)
    assert delayed.elapsed_ticks == 1
    assert delayed.progress == 0.0
    assert delayed.last_evidence.evidence_count == 1

    assert {:ok, transit} = LiveResolutionManager.fetch(departure.transit_region)
    assert transit.summary.identity_commitments[mover].energy < 0.8

    assert %{events: _} = CoarseTravel.advance(1, travel)
    assert {:ok, resumed} = CoarseTravel.journey(mover, travel)
    assert resumed.progress == 1.0
    assert resumed.last_evidence.evidence_count == 0
  end
end
