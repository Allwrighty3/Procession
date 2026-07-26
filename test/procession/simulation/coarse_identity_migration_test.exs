defmodule Procession.Simulation.CoarseIdentityMigrationTest do
  use ExUnit.Case, async: false

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  defp physical(id, position, inventory, consumed, energy) do
    %{
      id: id,
      position: position,
      energy: energy,
      mobility: 0.8,
      inventory: inventory,
      consumed: consumed
    }
  end

  defp stop_if_present(id) do
    if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
  end

  test "manager transfers exact anchored commitments without changing global stocks" do
    manager = String.to_atom(unique("migration_manager"))
    source_id = unique("source")
    destination_id = unique("destination")
    mover = unique("mover")
    partner = unique("partner")
    resident = unique("resident")

    assert {:ok, _pid} = LiveResolutionManager.start_link(name: manager)

    source =
      MultiResolutionRegion.new(
        id: source_id,
        entities: [
          physical(mover, {1, 1}, 0.4, 0.2, 0.6),
          physical(partner, {2, 1}, 0.1, 0.1, 0.8)
        ],
        resources: [%{id: unique("source_food"), position: {0, 0}, quantity: 2.0}],
        social_relations: %{
          {mover, partner, :presence} => %{confidence: 0.9, persistence: 1.0}
        }
      )
      |> LiveResolutionManager.compress_region()
      |> MultiResolutionRegion.make_inert()

    destination =
      MultiResolutionRegion.new(
        id: destination_id,
        entities: [physical(resident, {4, 4}, 0.3, 0.05, 0.7)],
        resources: [%{id: unique("destination_food"), position: {4, 4}, quantity: 1.5}]
      )
      |> LiveResolutionManager.compress_region()
      |> MultiResolutionRegion.make_inert()

    assert {:ok, _} = LiveResolutionManager.put(source, manager)
    assert {:ok, _} = LiveResolutionManager.put(destination, manager)

    total_before = source.summary.total_stock + destination.summary.total_stock
    population_before = source.summary.population + destination.summary.population

    assert {:ok, _} =
             LiveResolutionManager.transfer_identity(
               mover,
               source_id,
               destination_id,
               [],
               manager
             )

    assert {:ok, moved_source} = LiveResolutionManager.fetch(source_id, manager)
    assert {:ok, moved_destination} = LiveResolutionManager.fetch(destination_id, manager)

    refute mover in moved_source.summary.identity_anchors
    assert mover in moved_destination.summary.identity_anchors
    assert moved_destination.summary.identity_commitments[mover].inventory == 0.4
    assert moved_destination.summary.identity_commitments[mover].consumed == 0.2
    assert moved_source.summary.population == 1
    assert moved_destination.summary.population == 2

    assert_in_delta(
      moved_source.summary.total_stock + moved_destination.summary.total_stock,
      total_before,
      1.0e-9
    )

    assert moved_source.summary.population + moved_destination.summary.population == population_before
    assert LiveResolutionManager.dormant_identity_locations(manager)[mover] == destination_id
  end

  test "invalid transfer leaves both compressed regions unchanged" do
    manager = String.to_atom(unique("migration_manager"))
    source_id = unique("source")
    destination_id = unique("destination")
    resident = unique("resident")

    assert {:ok, _pid} = LiveResolutionManager.start_link(name: manager)

    source =
      MultiResolutionRegion.new(id: source_id, entities: [physical(resident, {0, 0}, 0.0, 0.0, 0.7)])
      |> LiveResolutionManager.compress_region()
      |> MultiResolutionRegion.make_inert()

    destination =
      MultiResolutionRegion.new(id: destination_id, entities: [])
      |> LiveResolutionManager.compress_region()
      |> MultiResolutionRegion.make_inert()

    assert {:ok, _} = LiveResolutionManager.put(source, manager)
    assert {:ok, _} = LiveResolutionManager.put(destination, manager)
    before = LiveResolutionManager.trace(manager)

    assert {:error, :identity_not_anchored_in_source} =
             LiveResolutionManager.transfer_identity(
               unique("missing"),
               source_id,
               destination_id,
               [],
               manager
             )

    assert LiveResolutionManager.trace(manager) == before
  end

  test "lifecycle moves the individual archive and destination activation restores identity" do
    source_id = unique("source")
    destination_id = unique("destination")
    mover = unique("mover")
    partner = unique("partner")
    resident = unique("resident")

    on_exit(fn ->
      Enum.each([mover, partner, resident], &stop_if_present/1)

      Enum.each([source_id, destination_id], fn region_id ->
        case LiveResolutionManager.fetch(region_id) do
          {:ok, region} -> Enum.each(Map.keys(region.entities), &stop_if_present/1)
          _ -> :ok
        end
      end)
    end)

    assert {:ok, _} =
             EntitySupervisor.start_entity(mover, %{
               name: "Migrating Anchor",
               type: :npc,
               traits: %{identity_marker: 0.9}
             })

    assert {:ok, _} = EntitySupervisor.start_entity(partner, %{name: "Partner", type: :npc})
    assert {:ok, _} = EntitySupervisor.start_entity(resident, %{name: "Resident", type: :npc})

    source =
      MultiResolutionRegion.new(
        id: source_id,
        entities: [
          physical(mover, {1, 1}, 0.35, 0.1, 0.65),
          physical(partner, {2, 1}, 0.0, 0.0, 0.8)
        ],
        social_relations: %{
          {mover, partner, :presence} => %{confidence: 0.9, persistence: 1.0}
        }
      )

    destination =
      MultiResolutionRegion.new(
        id: destination_id,
        entities: [physical(resident, {3, 3}, 0.0, 0.0, 0.75)]
      )

    assert {:ok, _} = LiveResolutionManager.put(source)
    assert {:ok, _} = LiveResolutionManager.put(destination)
    assert {:ok, _} = RegionActivationLifecycle.deactivate(source_id)
    assert {:ok, _} = RegionActivationLifecycle.deactivate(destination_id)

    assert {:ok, _} = RegionActivationLifecycle.migrate(mover, source_id, destination_id)

    assert {:ok, source_archive} = RegionActivationLifecycle.archive(source_id)
    assert {:ok, destination_archive} = RegionActivationLifecycle.archive(destination_id)
    refute Map.has_key?(source_archive.snapshots, mover)
    assert Map.has_key?(destination_archive.snapshots, mover)

    assert {:ok, %{resolution: :live}} = RegionActivationLifecycle.activate(destination_id, 91)
    assert EntitySupervisor.exists?(mover)

    restored = Entity.get_state(mover)
    assert restored.name == "Migrating Anchor"
    assert restored.location == destination_id
    assert restored.traits.identity_marker == 0.9
    assert_in_delta restored.metadata.physical_state.inventory, 0.35, 1.0e-9
  end
end
