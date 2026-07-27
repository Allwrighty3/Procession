defmodule Procession.Simulation.ThreeRegionMigrationExperiment do
  @moduledoc """
  Runs a small multi-resolution migration world using the production dormant locomotion path.

  Three anchored identities begin in three connected inert regions. Their developmental
  minds are preconditioned only through repeated sensory, motor, and consequence cycles;
  no identity stores a destination, route plan, journey-complete flag, or scripted action.
  The experiment then advances coarse travel and bounded dormant cognition together and
  reports observable decisions, movement, bodily state, service pressure, and causal traces.

  The isolated harness seeds inert archives directly because it is an experiment fixture,
  not a production world-generation API. After setup, all movement and mind persistence use
  `CoarseTravel`, `DormantLocomotionBatch`, and `RegionActivationLifecycle` normally.
  """

  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.DormantLocomotionBatch
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle

  @regions [:western_hollow, :river_market, :eastern_ridge]
  @identities [
    %{id: "orin", region: :western_hollow, energy: 0.9, inventory: 0.6, history: :east_favored},
    %{id: "mara", region: :river_market, energy: 0.45, inventory: 0.1, history: :uncommitted},
    %{id: "tess", region: :eastern_ridge, energy: 0.72, inventory: 0.3, history: :west_favored}
  ]

  @default_ticks 24
  @default_budget 2
  @training_cycles 96

  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    ticks = positive(Keyword.get(opts, :ticks, @default_ticks), @default_ticks)
    budget = non_negative(Keyword.get(opts, :budget, @default_budget), @default_budget)
    cadence = positive(Keyword.get(opts, :cadence, 1), 1)
    seed = Keyword.get(opts, :seed, 41)

    world = start_world(seed)
    started_at = System.monotonic_time(:microsecond)

    {tick_traces, totals} =
      Enum.reduce(1..ticks, {[], initial_totals()}, fn tick, {traces, totals} ->
        travel = CoarseTravel.advance(1, world.travel)

        batch =
          if rem(tick, cadence) == 0 do
            DormantLocomotionBatch.run(tick, &exits/2,
              travel_server: world.travel,
              lifecycle_server: world.lifecycle,
              resolution_server: world.manager,
              budget: budget,
              loop_opts: [seed: seed, output_exploration: 0.08]
            )
          else
            %{tick: tick, waiting: waiting_count(world.travel), attempted: 0, succeeded: 0, failed: 0,
              deferred: waiting_count(world.travel), selected: [], results: []}
          end

        locations = LiveResolutionManager.dormant_identity_locations(world.manager)
        commitments = commitments_by_identity(world.manager, locations)
        trace = tick_trace(tick, travel, batch, locations, commitments)
        {[trace | traces], add_totals(totals, trace)}
      end)

    elapsed_us = System.monotonic_time(:microsecond) - started_at
    traces = Enum.reverse(tick_traces)
    final_locations = LiveResolutionManager.dormant_identity_locations(world.manager)
    final_journeys = CoarseTravel.trace(world.travel).journeys

    stop_world(world)

    %{
      experiment: :three_region_migration,
      ticks: ticks,
      budget: budget,
      cadence: cadence,
      seed: seed,
      regions: @regions,
      identities: Enum.map(@identities, &Map.take(&1, [:id, :region, :energy, :inventory, :history])),
      destination_metadata_present?: false,
      totals: Map.put(totals, :runtime_us, elapsed_us),
      final_locations: final_locations,
      final_journeys: final_journeys,
      distinct_final_regions: final_locations |> Map.values() |> Enum.uniq() |> length(),
      traces: traces
    }
  end

  defp start_world(seed) do
    suffix = System.unique_integer([:positive, :monotonic])
    manager = String.to_atom("migration_manager_#{suffix}")
    lifecycle = String.to_atom("migration_lifecycle_#{suffix}")
    travel = String.to_atom("migration_travel_#{suffix}")

    {:ok, _} = LiveResolutionManager.start_link(name: manager)
    {:ok, _} = RegionActivationLifecycle.start_link(name: lifecycle, resolution_server: manager)
    {:ok, _} = CoarseTravel.start_link(name: travel, resolution_server: manager, lifecycle_server: lifecycle)

    minds = Map.new(@identities, fn profile -> {profile.id, trained_snapshot(profile, seed)} end)
    put_regions(manager)
    put_archives(lifecycle, minds)
    put_waiting_journeys(travel)

    %{manager: manager, lifecycle: lifecycle, travel: travel}
  end

  defp put_regions(manager) do
    Enum.each(@regions, fn region_id ->
      residents = Enum.filter(@identities, &(&1.region == region_id))

      region =
        MultiResolutionRegion.new(id: region_id, entities: [])
        |> MultiResolutionRegion.compress()
        |> MultiResolutionRegion.make_inert()

      commitments =
        Map.new(residents, fn profile ->
          {profile.id,
           %{
             position: {0, 0},
             energy: profile.energy,
             mobility: 0.85,
             inventory: profile.inventory,
             consumed: 0.0
           }}
        end)

      summary =
        region.summary
        |> Map.put(:identity_anchors, Enum.map(residents, & &1.id))
        |> Map.put(:identity_commitments, commitments)
        |> Map.put(:population, length(residents))
        |> Map.put(:local_resource_pressure, resource_pressure(region_id))

      {:ok, _} = LiveResolutionManager.put(%{region | summary: summary}, manager)
    end)
  end

  defp put_archives(lifecycle, minds) do
    :sys.replace_state(lifecycle, fn state ->
      archives =
        Map.new(@regions, fn region_id ->
          residents = Enum.filter(@identities, &(&1.region == region_id))
          ids = Enum.map(residents, & &1.id)

          archive = %{
            snapshots: Map.new(ids, &{&1, %{location: region_id}}),
            mind_snapshots: Map.take(minds, ids),
            population_minds: nil,
            compressed_at_tick: 0,
            stopped_entity_ids: ids
          }

          {region_id, archive}
        end)

      %{state | archives: archives}
    end)
  end

  defp put_waiting_journeys(travel) do
    journeys =
      Map.new(@identities, fn profile ->
        {profile.id,
         %{
           identity_id: profile.id,
           origin: profile.region,
           from: profile.region,
           to: nil,
           current_region: profile.region,
           transit_region: nil,
           episode_elapsed_ticks: 0,
           elapsed_ticks: 0,
           segment_elapsed_ticks: 0,
           segment_progress: 0.0,
           segment_extent: 0.0,
           total_ticks: 0,
           next_progress_factor: 1.0,
           segments_crossed: 0,
           status: :awaiting_direction,
           route_profile: %{},
           last_outcome: :observing_region_boundary
         }}
      end)

    :sys.replace_state(travel, &%{&1 | journeys: journeys})
  end

  defp trained_snapshot(profile, seed) do
    base =
      DevelopmentalSensorimotorLoop.new(
        field_opts: [
          micro_nodes: 96,
          input_width: 4,
          encoding_salt: {:migration_history, profile.id},
          output_source_threshold: 0.0,
          output_edge_retention: 1.0,
          output_plasticity_budget: 0.5
        ],
        body_opts: [initial_coordination: 1.0]
      )

    target = history_direction(profile.history)

    trained =
      if is_nil(target) do
        base
      else
        Enum.reduce(1..@training_cycles, base, fn tick, loop ->
          sensed = DevelopmentalSensorimotorLoop.sense(loop, training_features(profile))

          {emitted, outcome} =
            DevelopmentalSensorimotorLoop.emit(sensed, tick,
              seed: seed + :erlang.phash2(profile.id, 10_000),
              output_exploration: 1.0
            )

          coherence = if outcome.displaced? and outcome.direction == target, do: 1.0, else: -0.25

          DevelopmentalSensorimotorLoop.feedback(
            emitted,
            [
              {:signal, {:boundary_response, if(outcome.displaced?, do: :movement, else: :none)}, 1.0},
              {:signal, {:observed_direction, outcome.direction}, 1.0}
            ],
            coherence
          )
        end)
      end

    DevelopmentalMindSnapshot.capture(trained)
  end

  defp training_features(profile) do
    [
      {:signal, :region_boundary, 1.0},
      {:signal, {:body_energy, bucket(profile.energy)}, profile.energy},
      {:signal, {:body_mobility, :high}, 0.85},
      {:signal, {:carried_stock, bucket(profile.inventory)}, max(0.1, profile.inventory)},
      {:signal, {:perceived_exit_direction, :east}, 1.0},
      {:signal, {:perceived_exit_direction, :west}, 1.0}
    ]
  end

  defp exits(_identity_id, :western_hollow) do
    [exit(:east, :river_market, 2, travel_energy_decay: 0.004, route_pressure: 0.1)]
  end

  defp exits(_identity_id, :river_market) do
    [
      exit(:west, :western_hollow, 2, travel_energy_decay: 0.002, route_pressure: 0.0),
      exit(:east, :eastern_ridge, 3, travel_energy_decay: 0.012, route_pressure: 0.8,
        travel_demand: 0.03)
    ]
  end

  defp exits(_identity_id, :eastern_ridge) do
    [exit(:west, :river_market, 3, travel_energy_decay: 0.01, route_pressure: 0.5)]
  end

  defp exits(_identity_id, _region), do: []

  defp exit(direction, region_id, extent, opts) do
    %{direction: direction, region_id: region_id, segment_extent: extent, route_opts: opts}
  end

  defp tick_trace(tick, travel, batch, locations, commitments) do
    decisions =
      Enum.map(batch.results, fn
        {identity, {:ok, result}} ->
          %{
            identity: identity,
            status: :ok,
            action: result.decision.action,
            observed_direction: Map.get(result.decision, :observed_direction),
            execution: result.execution
          }

        {identity, {:error, reason}} ->
          %{identity: identity, status: :error, reason: reason}
      end)

    %{
      tick: tick,
      travel_events: travel.events,
      waiting: batch.waiting,
      attempted: batch.attempted,
      succeeded: batch.succeeded,
      failed: batch.failed,
      deferred: batch.deferred,
      decisions: decisions,
      locations: locations,
      commitments: commitments
    }
  end

  defp commitments_by_identity(manager, locations) do
    Map.new(locations, fn {identity, region_id} ->
      commitment =
        case LiveResolutionManager.fetch(region_id, manager) do
          {:ok, region} -> region.summary |> Map.get(:identity_commitments, %{}) |> Map.get(identity, %{})
          _ -> %{}
        end

      {identity, Map.take(commitment, [:energy, :mobility, :inventory, :consumed])}
    end)
  end

  defp initial_totals do
    %{attempted: 0, succeeded: 0, failed: 0, deferred: 0, movements: 0, remains: 0,
      entered_regions: 0, stranded: 0}
  end

  defp add_totals(totals, trace) do
    movements = Enum.count(trace.decisions, &(&1[:action] == :continue))
    remains = Enum.count(trace.decisions, &(&1[:action] == :remain))
    entered = Enum.count(trace.travel_events, &match?({:entered_region, _, _}, &1))
    stranded = Enum.count(trace.travel_events, &match?({:stranded, _, _}, &1))

    totals
    |> Map.update!(:attempted, &(&1 + trace.attempted))
    |> Map.update!(:succeeded, &(&1 + trace.succeeded))
    |> Map.update!(:failed, &(&1 + trace.failed))
    |> Map.update!(:deferred, &(&1 + trace.deferred))
    |> Map.update!(:movements, &(&1 + movements))
    |> Map.update!(:remains, &(&1 + remains))
    |> Map.update!(:entered_regions, &(&1 + entered))
    |> Map.update!(:stranded, &(&1 + stranded))
  end

  defp waiting_count(travel) do
    travel |> CoarseTravel.trace() |> DormantLocomotionBatch.waiting_identities() |> length()
  end

  defp stop_world(world) do
    Enum.each([world.travel, world.lifecycle, world.manager], fn name ->
      case Process.whereis(name) do
        pid when is_pid(pid) -> GenServer.stop(pid, :normal)
        _ -> :ok
      end
    end)
  end

  defp history_direction(:east_favored), do: :east
  defp history_direction(:west_favored), do: :west
  defp history_direction(:uncommitted), do: nil

  defp resource_pressure(:western_hollow), do: 0.65
  defp resource_pressure(:river_market), do: 0.15
  defp resource_pressure(:eastern_ridge), do: 0.35

  defp bucket(value) when value < 0.25, do: :low
  defp bucket(value) when value < 0.75, do: :middle
  defp bucket(_value), do: :high

  defp positive(value, _fallback) when is_integer(value) and value > 0, do: value
  defp positive(_value, fallback), do: fallback
  defp non_negative(value, _fallback) when is_integer(value) and value >= 0, do: value
  defp non_negative(_value, fallback), do: fallback
end
