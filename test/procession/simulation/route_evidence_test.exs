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

  defp physical(id, position, inventory, energy, mobility) do
    %{
      id: id,
      position: position,
      energy: energy,
      mobility: mobility,
      inventory: inventory,
      consumed: 0.0
    }
  end

  defp setup_world(opts \\ []) do
    manager = String.to_atom(unique("evidence_manager"))
    lifecycle = String.to_atom(unique("evidence_lifecycle"))
    travel = String.to_atom(unique("evidence_travel"))
    evidence = String.to_atom(unique("route_evidence"))
    source = unique("source")
    destination = unique("destination")
    alternate = unique("alternate")
    mover = unique("mover")
    partner = unique("partner")
    energy = Keyword.get(opts, :energy, 0.8)
    mobility = Keyword.get(opts, :mobility, 0.8)

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
        entities: [
          physical(mover, {0, 0}, 0.2, energy, mobility),
          physical(partner, {1, 0}, 0.0, 0.8, 0.8)
        ],
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

  defp washed_out_condition do
    %{
      cause: :flood_deposited_timber,
      affected_extent: 0.8,
      material_resistance: 0.9,
      surface_instability: 0.7,
      displacement: 0.5,
      visibility_loss: 0.2,
      environmental_intensity: 0.6
    }
  end

  test "expiring pressure and one-shot resource evidence affect only grounded ticks" do
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
               3,
               world.evidence
             )

    first = RouteEvidence.advance_travel(1, world.travel, world.evidence)
    assert Enum.any?(first.evidence_events, &match?({:route_effects, _, _}, &1))

    assert {:ok, transit_after_first} =
             LiveResolutionManager.fetch(departure.transit_region, world.manager)

    assert transit_after_first.summary.external_inflow >= 0.05

    second = RouteEvidence.advance_travel(2, world.travel, world.evidence)
    assert second.evidence_events == []
    assert RouteEvidence.route(world.source, world.destination, 4, world.evidence).sources == []
  end

  test "physical conditions remain stored facts while experienced resistance depends on traveler" do
    capable = setup_world(energy: 0.95, mobility: 0.95)
    limited = setup_world(energy: 0.35, mobility: 0.2)

    for world <- [capable, limited] do
      assert {:ok, _} =
               CoarseTravel.depart(
                 world.mover,
                 world.source,
                 world.destination,
                 4,
                 [travel_demand: 0.0, travel_energy_decay: 0.0],
                 world.travel
               )

      assert {:ok, _} =
               RouteEvidence.publish(
                 world.source,
                 world.destination,
                 :flood_debris,
                 %{conditions: [washed_out_condition()]},
                 1,
                 2,
                 world.evidence
               )
    end

    capable_result = RouteEvidence.advance_travel(1, capable.travel, capable.evidence)
    limited_result = RouteEvidence.advance_travel(1, limited.travel, limited.evidence)

    {:route_effects, _, capable_details} =
      Enum.find(capable_result.evidence_events, &match?({:route_effects, _, _}, &1))

    {:route_effects, _, limited_details} =
      Enum.find(limited_result.evidence_events, &match?({:route_effects, _, _}, &1))

    capable_resistance = hd(capable_details.experienced_conditions).experienced_resistance
    limited_resistance = hd(limited_details.experienced_conditions).experienced_resistance

    assert limited_resistance > capable_resistance

    stored_capable = RouteEvidence.route(capable.source, capable.destination, 1, capable.evidence)
    stored_limited = RouteEvidence.route(limited.source, limited.destination, 1, limited.evidence)
    assert stored_capable.conditions == stored_limited.conditions

    assert {:ok, capable_journey} = CoarseTravel.journey(capable.mover, capable.travel)
    assert {:ok, limited_journey} = CoarseTravel.journey(limited.mover, limited.travel)
    assert capable_journey.status == :in_transit
    assert limited_journey.status == :in_transit
  end

  test "interpretive obstruction and blocked inputs are rejected without killing the owner" do
    world = setup_world()

    assert {:error, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :closed_road,
               %{blocked: true},
               1,
               2,
               world.evidence
             )

    assert {:error, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :obstruction_label,
               %{obstruction: %{cause: :tree}},
               1,
               2,
               world.evidence
             )

    assert {:error, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :interpreted_condition,
               %{conditions: [%{cause: :tree, severity: 1.0}]},
               1,
               2,
               world.evidence
             )

    assert RouteEvidence.trace(world.evidence) == %{}
  end

  test "causal conditions increase physical cost without deciding journey status" do
    world = setup_world(energy: 0.8, mobility: 0.6)

    assert {:ok, departure} =
             CoarseTravel.depart(
               world.mover,
               world.source,
               world.destination,
               4,
               [travel_demand: 0.0, travel_energy_decay: 0.0],
               world.travel
             )

    assert {:ok, before_region} =
             LiveResolutionManager.fetch(departure.transit_region, world.manager)

    before = before_region.summary.identity_commitments[world.mover]

    assert {:ok, _} =
             RouteEvidence.publish(
               world.source,
               world.destination,
               :washed_out_crossing,
               %{conditions: [washed_out_condition()]},
               1,
               3,
               world.evidence
             )

    result = RouteEvidence.advance_travel(1, world.travel, world.evidence)

    {:route_effects, _, details} =
      Enum.find(result.evidence_events, &match?({:route_effects, _, _}, &1))

    assert %{cause: :flood_deposited_timber, experienced_resistance: resistance} =
             hd(details.experienced_conditions)

    assert resistance > 0.0
    assert {:ok, journey} = CoarseTravel.journey(world.mover, world.travel)
    assert journey.status == :in_transit
    assert journey.elapsed_ticks == 1

    assert {:ok, after_region} =
             LiveResolutionManager.fetch(departure.transit_region, world.manager)

    after_commitment = after_region.summary.identity_commitments[world.mover]
    assert after_commitment.energy < before.energy
    assert after_commitment.consumed > before.consumed
  end

  test "observed alternate route changes destination without teleportation" do
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
  end
end
