defmodule Procession.Simulation.DormantLocomotionSchedulerTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.DormantLocomotionScheduler
  alias Procession.Simulation.DormantMindArchive
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle

  defp unique(prefix),
    do: String.to_atom("#{prefix}_#{System.unique_integer([:positive, :monotonic])}")

  defp setup_dormant_waiting_identity() do
    manager = unique("dormant_decision_manager")
    lifecycle = unique("dormant_decision_lifecycle")
    travel = unique("dormant_decision_travel")
    identity = "traveler_#{System.unique_integer([:positive, :monotonic])}"
    region_id = "region_#{System.unique_integer([:positive, :monotonic])}"

    assert {:ok, _} = LiveResolutionManager.start_link(name: manager)
    assert {:ok, _} = RegionActivationLifecycle.start_link(name: lifecycle, resolution_server: manager)

    assert {:ok, _} =
             CoarseTravel.start_link(
               name: travel,
               resolution_server: manager,
               lifecycle_server: lifecycle
             )

    snapshot =
      []
      |> DevelopmentalSensorimotorLoop.new()
      |> DevelopmentalMindSnapshot.capture()

    region =
      MultiResolutionRegion.new(id: region_id, entities: [])
      |> MultiResolutionRegion.compress()
      |> MultiResolutionRegion.make_inert()

    summary =
      region.summary
      |> Map.put(:identity_anchors, [identity])
      |> Map.put(:identity_commitments, %{
        identity => %{
          position: {0, 0},
          energy: 0.8,
          mobility: 0.7,
          inventory: 0.4,
          consumed: 0.0
        }
      })
      |> Map.put(:population, 1)

    assert {:ok, _} = LiveResolutionManager.put(%{region | summary: summary}, manager)

    :sys.replace_state(lifecycle, fn state ->
      archive = %{
        snapshots: %{},
        mind_snapshots: %{identity => snapshot},
        population_minds: nil,
        compressed_at_tick: 0,
        stopped_entity_ids: [identity]
      }

      put_in(state.archives[region_id], archive)
    end)

    :sys.replace_state(travel, fn state ->
      journey = %{
        identity_id: identity,
        origin: region_id,
        from: region_id,
        to: nil,
        current_region: region_id,
        transit_region: nil,
        episode_elapsed_ticks: 3,
        elapsed_ticks: 0,
        segment_elapsed_ticks: 0,
        segment_progress: 0.0,
        segment_extent: 0.0,
        total_ticks: 0,
        next_progress_factor: 1.0,
        segments_crossed: 1,
        status: :awaiting_direction,
        route_profile: %{},
        last_outcome: :entered_region
      }

      put_in(state.journeys[identity], journey)
    end)

    %{
      manager: manager,
      lifecycle: lifecycle,
      travel: travel,
      identity: identity,
      region: region_id,
      snapshot: snapshot
    }
  end

  test "restores one dormant mind, emits once, and persists it without spawning a live mind" do
    world = setup_dormant_waiting_identity()

    assert {:ok, result} =
             DormantLocomotionScheduler.decide(
               world.identity,
               [],
               10,
               travel_server: world.travel,
               lifecycle_server: world.lifecycle,
               resolution_server: world.manager,
               loop_opts: [seed: 19, output_exploration: 1.0]
             )

    assert result.decision.action == :remain
    assert result.live_mind_process_started? == false
    assert result.snapshot_region == world.region

    assert {:ok, updated} =
             DormantMindArchive.fetch(world.region, world.identity, world.lifecycle)

    refute updated == world.snapshot

    restored = DevelopmentalMindSnapshot.restore(updated)
    assert restored.cycles == 1
    assert restored.pending_output == nil

    assert Registry.lookup(
             Procession.EntityRegistry,
             {:sensorimotor, world.identity}
           ) == []
  end

  test "archive replacement rejects a stale dormant mind snapshot" do
    world = setup_dormant_waiting_identity()
    first = world.snapshot

    replacement =
      first
      |> DevelopmentalMindSnapshot.restore()
      |> Map.put(:cycles, 9)
      |> DevelopmentalMindSnapshot.capture()

    assert :ok =
             DormantMindArchive.replace(
               world.region,
               world.identity,
               first,
               replacement,
               world.lifecycle
             )

    assert {:error, :stale_dormant_mind_snapshot} =
             DormantMindArchive.replace(
               world.region,
               world.identity,
               first,
               first,
               world.lifecycle
             )

    assert {:ok, ^replacement} =
             DormantMindArchive.fetch(world.region, world.identity, world.lifecycle)
  end
end
