defmodule Procession.Simulation.CascadingRegionalChangeExperiment do
  @moduledoc """
  Runs a three-region dormant migration ecosystem where population changes alter later
  production, stock, support, bodily state, and subsequent locomotion opportunities.

  No destination, settlement, occupation, or journey-complete metadata is stored. The
  experiment uses the production dormant locomotion, coarse travel, lifecycle, and resolution
  owners for every consequential decision and migration.
  """

  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.DormantLocomotionBatch
  alias Procession.Simulation.DormantMindArchive
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle

  @regions [:west_fields, :crossroads, :east_refuge]
  @training_cycles 96
  @profiles [
    %{id: "orin", region: :west_fields, energy: 0.88, inventory: 0.35, history: :east},
    %{id: "lena", region: :west_fields, energy: 0.62, inventory: 0.12, history: :east},
    %{id: "pavel", region: :west_fields, energy: 0.48, inventory: 0.08, history: :uncommitted},
    %{id: "mara", region: :crossroads, energy: 0.54, inventory: 0.10, history: :east},
    %{id: "tess", region: :east_refuge, energy: 0.78, inventory: 0.25, history: :west},
    %{id: "sela", region: :east_refuge, energy: 0.44, inventory: 0.06, history: :west}
  ]

  def run(opts \\ []) do
    ticks = positive(Keyword.get(opts, :ticks, 64), 64)
    budget = non_negative(Keyword.get(opts, :budget, 3), 3)
    cadence = positive(Keyword.get(opts, :cadence, 1), 1)
    seed = Keyword.get(opts, :seed, 41)
    world = start_world(seed)
    started_at = System.monotonic_time(:microsecond)
    initial_locations = LiveResolutionManager.dormant_identity_locations(world.manager)

    {traces, _locations, totals} =
      Enum.reduce(1..ticks, {[], initial_locations, totals()}, fn tick,
                                                                 {traces, previous, totals} ->
        regional = evolve_regions(world.manager)
        travel = CoarseTravel.advance(1, world.travel)
        batch = run_batch(world, tick, cadence, budget, seed)
        locations = LiveResolutionManager.dormant_identity_locations(world.manager)

        trace = %{
          tick: tick,
          regional: regional,
          decisions: decisions(batch),
          attempted: batch.attempted,
          succeeded: batch.succeeded,
          failed: batch.failed,
          deferred: batch.deferred,
          travel_events: travel.events,
          location_changes: location_changes(previous, locations),
          locations: locations,
          commitments: commitments(world.manager, locations),
          journeys: compact_journeys(CoarseTravel.trace(world.travel).journeys)
        }

        {[trace | traces], locations, accumulate(totals, trace)}
      end)

    elapsed = System.monotonic_time(:microsecond) - started_at
    traces = Enum.reverse(traces)
    final_locations = LiveResolutionManager.dormant_identity_locations(world.manager)

    result = %{
      experiment: :cascading_regional_change,
      ticks: ticks,
      budget: budget,
      cadence: cadence,
      seed: seed,
      regions: @regions,
      identities: Enum.map(@profiles, &Map.take(&1, [:id, :region, :energy, :inventory, :history])),
      destination_metadata_present?: false,
      totals: totals |> Map.put(:runtime_us, elapsed) |> Map.put(:runtime_us_per_tick, elapsed / ticks),
      final_locations: final_locations,
      final_regions: regional_state(world.manager),
      snapshot_metrics: snapshot_metrics(world.lifecycle, final_locations),
      live_entity_process_peak: 0,
      analysis: analyze(traces),
      traces: traces
    }

    stop_world(world)
    result
  end

  defp run_batch(world, tick, cadence, budget, seed) do
    if rem(tick, cadence) == 0 do
      DormantLocomotionBatch.run(@training_cycles + tick, exit_provider(world.manager),
        travel_server: world.travel,
        lifecycle_server: world.lifecycle,
        resolution_server: world.manager,
        budget: budget,
        loop_opts: [seed: seed, output_exploration: 0.08]
      )
    else
      waiting = waiting_count(world.travel)

      %{
        tick: @training_cycles + tick,
        waiting: waiting,
        attempted: 0,
        succeeded: 0,
        failed: 0,
        deferred: waiting,
        selected: [],
        results: []
      }
    end
  end

  defp start_world(seed) do
    suffix = System.unique_integer([:positive, :monotonic])
    manager = String.to_atom("cascade_manager_#{suffix}")
    lifecycle = String.to_atom("cascade_lifecycle_#{suffix}")
    travel = String.to_atom("cascade_travel_#{suffix}")

    {:ok, _} = LiveResolutionManager.start_link(name: manager)
    {:ok, _} = RegionActivationLifecycle.start_link(name: lifecycle, resolution_server: manager)
    {:ok, _} = CoarseTravel.start_link(name: travel, resolution_server: manager, lifecycle_server: lifecycle)

    minds = Map.new(@profiles, &{&1.id, trained_snapshot(&1, seed)})
    seed_regions(manager)
    seed_archives(lifecycle, minds)
    seed_journeys(travel)
    %{manager: manager, lifecycle: lifecycle, travel: travel}
  end

  defp seed_regions(manager) do
    Enum.each(@regions, fn region_id ->
      residents = Enum.filter(@profiles, &(&1.region == region_id))

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

      region =
        MultiResolutionRegion.new(id: region_id, entities: [])
        |> MultiResolutionRegion.compress()
        |> MultiResolutionRegion.make_inert()

      summary =
        region.summary
        |> Map.put(:identity_anchors, Enum.map(residents, & &1.id))
        |> Map.put(:identity_commitments, commitments)
        |> Map.put(:population, length(residents))
        |> Map.merge(initial_conditions(region_id))

      {:ok, _} = LiveResolutionManager.put(%{region | summary: summary}, manager)
    end)
  end

  defp initial_conditions(:west_fields),
    do: %{regional_stock: 1.2, production_rate: 0.08, shelter_capacity: 2.0,
      regional_support: 0.5, local_resource_pressure: 0.35}

  defp initial_conditions(:crossroads),
    do: %{regional_stock: 0.65, production_rate: 0.025, shelter_capacity: 2.0,
      regional_support: 0.45, local_resource_pressure: 0.55}

  defp initial_conditions(:east_refuge),
    do: %{regional_stock: 1.0, production_rate: 0.04, shelter_capacity: 2.5,
      regional_support: 0.65, local_resource_pressure: 0.3}

  defp seed_archives(lifecycle, minds) do
    :sys.replace_state(lifecycle, fn state ->
      archives =
        Map.new(@regions, fn region_id ->
          ids = @profiles |> Enum.filter(&(&1.region == region_id)) |> Enum.map(& &1.id)

          {region_id,
           %{
             snapshots: Map.new(ids, &{&1, %{location: region_id}}),
             mind_snapshots: Map.take(minds, ids),
             population_minds: nil,
             compressed_at_tick: 0,
             stopped_entity_ids: ids
           }}
        end)

      %{state | archives: archives}
    end)
  end

  defp seed_journeys(travel) do
    journeys =
      Map.new(@profiles, fn profile ->
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

  defp evolve_regions(manager) do
    Map.new(@regions, fn region_id ->
      {:ok, region} = LiveResolutionManager.fetch(region_id, manager)
      summary = region.summary
      commitments = Map.get(summary, :identity_commitments, %{})
      population = map_size(commitments)
      production = number(summary, :production_rate) * population
      consumption = 0.055 * population
      stock = clamp(number(summary, :regional_stock) + production - consumption, 0.0, 4.0)
      capacity = max(0.5, number(summary, :shelter_capacity))
      crowding = max(0.0, population / capacity - 1.0)
      stock_per_person = if population == 0, do: stock, else: stock / population
      support = clamp(stock_per_person * 1.4 - crowding * 0.45, 0.0, 1.0)
      pressure = clamp(1.0 - support + crowding * 0.4, 0.0, 1.5)

      updated_commitments =
        Map.new(commitments, fn {identity, commitment} ->
          energy = clamp(number(commitment, :energy) + support * 0.025 - pressure * 0.035, 0.0, 1.0)
          inventory_delta = if stock_per_person > 0.2, do: 0.008, else: -0.006
          inventory = clamp(number(commitment, :inventory) + inventory_delta, 0.0, 1.0)
          {identity, commitment |> Map.put(:energy, energy) |> Map.put(:inventory, inventory)}
        end)

      next_summary =
        summary
        |> Map.put(:identity_anchors, updated_commitments |> Map.keys() |> Enum.sort())
        |> Map.put(:identity_commitments, updated_commitments)
        |> Map.put(:population, population)
        |> Map.put(:regional_stock, stock)
        |> Map.put(:regional_support, support)
        |> Map.put(:local_resource_pressure, pressure)
        |> Map.put(:last_production, production)
        |> Map.put(:last_consumption, consumption)

      {:ok, _} = LiveResolutionManager.put(%{region | summary: next_summary}, manager)
      {region_id, regional_fields(next_summary)}
    end)
  end

  defp exit_provider(manager) do
    fn _identity, region_id ->
      pressure =
        case LiveResolutionManager.fetch(region_id, manager) do
          {:ok, region} -> number(region.summary, :local_resource_pressure)
          _ -> 0.0
        end

      exits(region_id, pressure)
    end
  end

  defp exits(:west_fields, pressure), do: [exit(:east, :crossroads, 2, pressure)]

  defp exits(:crossroads, pressure),
    do: [exit(:west, :west_fields, 2, pressure), exit(:east, :east_refuge, 3, pressure + 0.15)]

  defp exits(:east_refuge, pressure), do: [exit(:west, :crossroads, 3, pressure + 0.1)]
  defp exits(_, _), do: []

  defp exit(direction, region_id, extent, pressure) do
    pressure = clamp(pressure, 0.0, 1.5)

    %{
      direction: direction,
      region_id: region_id,
      segment_extent: extent,
      route_opts: [
        travel_energy_decay: 0.004 + pressure * 0.006,
        route_pressure: pressure,
        travel_demand: 0.01 + pressure * 0.015
      ]
    }
  end

  defp trained_snapshot(profile, seed) do
    loop =
      DevelopmentalSensorimotorLoop.new(
        field_opts: [
          micro_nodes: 96,
          input_width: 4,
          encoding_salt: {:cascade_history, profile.id},
          output_source_threshold: 0.0,
          output_edge_retention: 1.0,
          output_plasticity_budget: 0.5
        ],
        body_opts: [initial_coordination: 1.0]
      )

    trained =
      if profile.history == :uncommitted do
        loop
      else
        Enum.reduce(1..@training_cycles, loop, fn tick, current ->
          sensed = DevelopmentalSensorimotorLoop.sense(current, training_features(profile))

          {emitted, outcome} =
            DevelopmentalSensorimotorLoop.emit(sensed, tick,
              seed: seed + :erlang.phash2(profile.id, 10_000),
              output_exploration: 1.0
            )

          coherence = if outcome.displaced? and outcome.direction == profile.history, do: 1.0, else: -0.25

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

  defp decisions(batch) do
    Enum.map(batch.results, fn
      {identity, {:ok, result}} ->
        %{identity: identity, status: :ok, action: result.decision.action,
          direction: Map.get(result.decision, :observed_direction), execution: result.execution}

      {identity, {:error, reason}} ->
        %{identity: identity, status: :error, reason: reason}
    end)
  end

  defp commitments(manager, locations) do
    Map.new(locations, fn {identity, region_id} ->
      value =
        case LiveResolutionManager.fetch(region_id, manager) do
          {:ok, region} -> region.summary |> Map.get(:identity_commitments, %{}) |> Map.get(identity, %{})
          _ -> %{}
        end

      {identity, Map.take(value, [:energy, :mobility, :inventory, :consumed])}
    end)
  end

  defp compact_journeys(journeys) do
    Map.new(journeys, fn {identity, journey} ->
      {identity, Map.take(journey, [:status, :current_region, :from, :to, :segment_progress,
        :segment_extent, :elapsed_ticks, :segments_crossed, :last_outcome])}
    end)
  end

  defp location_changes(previous, current) do
    Enum.flat_map(current, fn {identity, location} ->
      case Map.get(previous, identity) do
        nil -> []
        ^location -> []
        old -> [%{identity: identity, from: old, to: location}]
      end
    end)
  end

  defp regional_state(manager) do
    Map.new(@regions, fn region_id ->
      {:ok, region} = LiveResolutionManager.fetch(region_id, manager)
      {region_id, regional_fields(region.summary)}
    end)
  end

  defp regional_fields(summary) do
    Map.take(summary, [:population, :regional_stock, :regional_support,
      :local_resource_pressure, :last_production, :last_consumption])
  end

  defp snapshot_metrics(lifecycle, locations) do
    Map.new(locations, fn {identity, region_id} ->
      case DormantMindArchive.fetch(region_id, identity, lifecycle) do
        {:ok, snapshot} ->
          {identity, %{bytes: :erlang.external_size(snapshot),
            cost: DevelopmentalMindSnapshot.cost(snapshot), retained: snapshot.metrics}}

        {:error, reason} ->
          {identity, %{error: reason}}
      end
    end)
  end

  defp analyze(traces) do
    decisions = Enum.flat_map(traces, & &1.decisions)
    directions = decisions |> Enum.filter(&(&1[:action] == :continue)) |> Enum.group_by(& &1.identity, & &1.direction)
    {deteriorations, recoveries} = energy_changes(traces)

    %{
      population_changed?: population_changed?(traces),
      cascading_feedback_observed?: cascading_feedback?(traces),
      dynamic_conditions_changed?: dynamic_conditions_changed?(traces),
      route_reversals: Enum.sum(Enum.map(directions, fn {_id, values} -> pair_count(values, &opposite?/2) end)),
      repeated_direction_choices: Enum.sum(Enum.map(directions, fn {_id, values} -> pair_count(values, &Kernel.==/2) end)),
      boundary_hesitation_ticks: Enum.count(decisions, &(&1[:action] == :remain)),
      bodily_deteriorations: deteriorations,
      bodily_recoveries: recoveries,
      distinct_regions_entered:
        traces |> Enum.flat_map(& &1.location_changes) |> Enum.map(& &1.to)
        |> Enum.reject(&match?({:transit, _, _, _}, &1)) |> Enum.uniq() |> length()
    }
  end

  defp population_changed?([first | _] = traces) do
    last = List.last(traces)
    Enum.any?(@regions, &(first.regional[&1].population != last.regional[&1].population))
  end

  defp population_changed?([]), do: false

  defp cascading_feedback?(traces) do
    traces
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.any?(fn [before, changed, later] ->
      Enum.any?(@regions, fn region ->
        before.regional[region].population != changed.regional[region].population and
          (changed.regional[region].last_production != later.regional[region].last_production or
             changed.regional[region].regional_support != later.regional[region].regional_support)
      end)
    end)
  end

  defp dynamic_conditions_changed?([first | _] = traces) do
    last = List.last(traces)
    Enum.any?(@regions, fn region ->
      first.regional[region].regional_stock != last.regional[region].regional_stock or
        first.regional[region].regional_support != last.regional[region].regional_support
    end)
  end

  defp dynamic_conditions_changed?([]), do: false

  defp energy_changes(traces) do
    traces
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce({0, 0}, fn [before, later], counts ->
      Enum.reduce(later.commitments, counts, fn {identity, current}, {down, up} ->
        previous = get_in(before.commitments, [identity, :energy])
        energy = Map.get(current, :energy)

        cond do
          is_number(previous) and is_number(energy) and energy < previous -> {down + 1, up}
          is_number(previous) and is_number(energy) and energy > previous -> {down, up + 1}
          true -> {down, up}
        end
      end)
    end)
  end

  defp pair_count(values, predicate) do
    values |> Enum.chunk_every(2, 1, :discard) |> Enum.count(fn [a, b] -> predicate.(a, b) end)
  end

  defp opposite?(:east, :west), do: true
  defp opposite?(:west, :east), do: true
  defp opposite?(_, _), do: false

  defp totals, do: %{attempted: 0, succeeded: 0, failed: 0, deferred: 0,
    location_changes: 0, entered_regions: 0}

  defp accumulate(totals, trace) do
    entered = Enum.count(trace.travel_events, &match?({:entered_region, _, _}, &1))

    totals
    |> Map.update!(:attempted, &(&1 + trace.attempted))
    |> Map.update!(:succeeded, &(&1 + trace.succeeded))
    |> Map.update!(:failed, &(&1 + trace.failed))
    |> Map.update!(:deferred, &(&1 + trace.deferred))
    |> Map.update!(:location_changes, &(&1 + length(trace.location_changes)))
    |> Map.update!(:entered_regions, &(&1 + entered))
  end

  defp waiting_count(travel) do
    travel |> CoarseTravel.trace() |> DormantLocomotionBatch.waiting_identities() |> length()
  end

  defp stop_world(world) do
    Enum.each([world.travel, world.lifecycle, world.manager], fn name ->
      if pid = Process.whereis(name), do: GenServer.stop(pid, :normal)
    end)
  end

  defp number(map, key) do
    case Map.get(map, key) do
      value when is_number(value) -> value * 1.0
      _ -> 0.0
    end
  end

  defp bucket(value) when value < 0.25, do: :low
  defp bucket(value) when value < 0.75, do: :middle
  defp bucket(_), do: :high
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
  defp positive(value, _fallback) when is_integer(value) and value > 0, do: value
  defp positive(_value, fallback), do: fallback
  defp non_negative(value, _fallback) when is_integer(value) and value >= 0, do: value
  defp non_negative(_value, fallback), do: fallback
end
