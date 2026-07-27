defmodule Procession.Simulation.CascadingRegionalChangeExperiment do
  @moduledoc """
  Runs a three-region dormant migration ecosystem where population changes alter later
  production, stock, support, bodily state, and therefore later locomotion opportunities.

  The experiment does not assign destinations, settlements, occupations, or migration goals.
  Region conditions are derived from resident count and low-level physical rates. Dormant
  identities perceive only bodily state and locally available boundary directions through the
  production dormant locomotion path.
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
  @profiles [
    %{id: "orin", region: :west_fields, energy: 0.88, inventory: 0.35, history: :east},
    %{id: "lena", region: :west_fields, energy: 0.62, inventory: 0.12, history: :east},
    %{id: "pavel", region: :west_fields, energy: 0.48, inventory: 0.08, history: :uncommitted},
    %{id: "mara", region: :crossroads, energy: 0.54, inventory: 0.10, history: :east},
    %{id: "tess", region: :east_refuge, energy: 0.78, inventory: 0.25, history: :west},
    %{id: "sela", region: :east_refuge, energy: 0.44, inventory: 0.06, history: :west}
  ]

  @training_cycles 96
  @default_ticks 64
  @default_budget 3

  def run(opts \\ []) do
    ticks = positive(Keyword.get(opts, :ticks, @default_ticks), @default_ticks)
    budget = non_negative(Keyword.get(opts, :budget, @default_budget), @default_budget)
    cadence = positive(Keyword.get(opts, :cadence, 1), 1)
    seed = Keyword.get(opts, :seed, 41)

    world = start_world(seed)
    started_at = System.monotonic_time(:microsecond)
    initial_locations = LiveResolutionManager.dormant_identity_locations(world.manager)

    {traces, _previous_locations, totals} =
      Enum.reduce(1..ticks, {[], initial_locations, initial_totals()}, fn tick,
                                                                         {traces,
                                                                          previous_locations,
                                                                          totals} ->
        regional = evolve_regions(world.manager)
        travel = CoarseTravel.advance(1, world.travel)

        batch =
          if rem(tick, cadence) == 0 do
            DormantLocomotionBatch.run(@training_cycles + tick, exits(world.manager),
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

        locations = LiveResolutionManager.dormant_identity_locations(world.manager)
        movements = location_changes(previous_locations, locations)
        commitments = commitments_by_identity(world.manager, locations)
        journeys = CoarseTravel.trace(world.travel).journeys

        trace = %{
          tick: tick,
          regional: regional,
          decisions: decisions(batch),
          attempted: batch.attempted,
          succeeded: batch.succeeded,
          failed: batch.failed,
          deferred: batch.deferred,
          travel_events: travel.events,
          location_changes: movements,
          locations: locations,
          commitments: commitments,
          journeys: compact_journeys(journeys)
        }

        {[trace | traces], locations, add_totals(totals, trace)}
      end)

    elapsed_us = System.monotonic_time(:microsecond) - started_at
    traces = Enum.reverse(traces)
    final_locations = LiveResolutionManager.dormant_identity_locations(world.manager)
    snapshot_metrics = snapshot_metrics(world.lifecycle, final_locations)
    analysis = analyze(traces)

    result = %{
      experiment: :cascading_regional_change,
      ticks: ticks,
      budget: budget,
      cadence: cadence,
      seed: seed,
      regions: @regions,
      identities: Enum.map(@profiles, &Map.take(&1, [:id, :region, :energy, :inventory, :history])),
      destination_metadata_present?: false,
      totals: totals |> Map.put(:runtime_us, elapsed_us) |> Map.put(:runtime_us_per_tick, elapsed_us / ticks),
      final_locations: final_locations,
      final_regions: regional_state(world.manager),
      snapshot_metrics: snapshot_metrics,
      live_entity_process_peak: 0,
      analysis: analysis,
      traces: traces
    }

    stop_world(world)
    result
  end

  defp start_world(seed) do
    suffix = System.unique_integer([:positive, :monotonic])
    manager = String.to_atom("cascade_manager_#{suffix}")
    lifecycle = String.to_atom("cascade_lifecycle_#{suffix}")
    travel = String.to_atom("cascade_travel_#{suffix}")

    {:ok, _} = LiveResolutionManager.start_link(name: manager)
    {:ok, _} = RegionActivationLifecycle.start_link(name: lifecycle, resolution_server: manager)
    {:ok, _} = CoarseTravel.start_link(name: travel, resolution_server: manager, lifecycle_server: lifecycle)

    minds = Map.new(@profiles, fn profile -> {profile.id, trained_snapshot(profile, seed)} end)
    put_regions(manager)
    put_archives(lifecycle, minds)
    put_waiting_journeys(travel)

    %{manager: manager, lifecycle: lifecycle, travel: travel}
  end

  defp put_regions(manager) do
    Enum.each(@regions, fn region_id ->
      residents = Enum.filter(@profiles, &(&1.region == region_id))

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
        |> Map.merge(initial_region_state(region_id))

      {:ok, _} = LiveResolutionManager.put(%{region | summary: summary}, manager)
    end)
  end

  defp initial_region_state(:west_fields),
    do: %{regional_stock: 1.2, production_rate: 0.08, shelter_capacity: 2.0, regional_support: 0.5,
      local_resource_pressure: 0.35}

  defp initial_region_state(:crossroads),
    do: %{regional_stock: 0.65, production_rate: 0.025, shelter_capacity: 2.0, regional_support: 0.45,
      local_resource_pressure: 0.55}

  defp initial_region_state(:east_refuge),
    do: %{regional_stock: 1.0, production_rate: 0.04, shelter_capacity: 2.5, regional_support: 0.65,
      local_resource_pressure: 0.3}

  defp put_archives(lifecycle, minds) do
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

  defp put_waiting_journeys(travel) do
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
      stock = number(summary, :regional_stock)
      production = number(summary, :production_rate) * population
      consumption = 0.055 * population
      next_stock = clamp(stock + production - consumption, 0.0, 4.0)
      shelter_capacity = max(0.5, number(summary, :shelter_capacity))
      crowding = max(0.0, population / shelter_capacity - 1.0)
      stock_per_person = if population == 0, do: next_stock, else: next_stock / population
      support = clamp(stock_per_person * 1.4 - crowding * 0.45, 0.0, 1.0)
      pressure = clamp(1.0 - support + crowding * 0.4, 0.0, 1.5)

      updated_commitments =
        Map.new(commitments, fn {identity_id, commitment} ->
          energy = number(commitment, :energy)
          delta = support * 0.025 - pressure * 0.035
          inventory_delta = if stock_per_person > 0.2, do: 0.008, else: -0.006

          {identity_id,
           commitment
           |> Map.put(:energy, clamp(energy + delta, 0.0, 1.0))
           |> Map.put(:inventory, clamp(number(commitment, :inventory) + inventory_delta, 0.0, 1.0))}
        end)

      updated_summary =
        summary
        |> Map.put(:identity_anchors, Map.keys(updated_commitments) |> Enum.sort())
        |> Map.put(:identity_commitments, updated_commitments)
        |> Map.put(:population, population)
        |> Map.put(:regional_stock, next_stock)
        |> Map.put(:regional_support, support)
        |> Map.put(:local_resource_pressure, pressure)
        |> Map.put(:last_production, production)
        |> Map.put(:last_consumption, consumption)

      {:ok, _} = LiveResolutionManager.put(%{region | summary: updated_summary}, manager)

      {region_id,
       Map.take(updated_summary, [
         :population,
         :regional_stock,
         :regional_support,
         :local_resource_pressure,
         :last_production,
         :last_consumption
       ])}
    end)
  end

  defp exits(manager) do
    fn _identity_id, region_id ->
      source_pressure =
        case LiveResolutionManager.fetch(region_id, manager) do
          {:ok, region} -> number(region.summary, :local_resource_pressure)
          _ -> 0.0
        end

      exits_for(region_id, source_pressure)
    end
  end

  defp exits_for(:west_fields, pressure),
    do: [exit(:east, :crossroads, 2, pressure)]

  defp exits_for(:crossroads, pressure),
    do: [exit(:west, :west_fields, 2, pressure), exit(:east, :east_refuge, 3, pressure + 0.15)]

  defp exits_for(:east_refuge, pressure),
    do: [exit(:west, :crossroads, 3, pressure + 0.1)]

  defp exits_for(_, _), do: []

  defp exit(direction, destination, extent, pressure) do
    %{
      direction: direction,
      region_id: destination,
      segment_extent: extent,
      route_opts: %{
        travel_energy_decay: 0.004 + clamp(pressure, 0.0, 1.5) * 0.006,
        route_pressure: clamp(pressure, 0.0, 1.5),
        travel_demand: 0.01 + clamp(pressure, 0.0, 1.5) * 0.015
      }
    }
  end

  defp trained_snapshot(profile, seed) do
    base =
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
      case profile.history do
        :uncommitted ->
          base

        target ->
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

  defp decisions(batch) do
    Enum.map(batch.results, fn
      {identity, {:ok, result}} ->
        %{
          identity: identity,
          status: :ok,
          action: result.decision.action,
          direction: Map.get(result.decision, :observed_direction),
          execution: result.execution
        }

      {identity, {:error, reason}} ->
        %{identity: identity, status: :error, reason: reason}
    end)
  end

  defp location_changes(previous, current) do
    Enum.flat_map(current, fn {identity, location} ->
      case Map.get(previous, identity) do
        nil -> []
        ^location -> []
        from -> [%{identity: identity, from: from, to: location}]
      end
    end)
  end

  defp compact_journeys(journeys) do
    Map.new(journeys, fn {identity, journey} ->
      {identity,
       Map.take(journey, [
         :status,
         :current_region,
         :from,
         :to,
         :segment_progress,
         :segment_extent,
         :elapsed_ticks,
         :segments_crossed,
         :last_outcome
       ])}
    end)
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

  defp regional_state(manager) do
    Map.new(@regions, fn region_id ->
      {:ok, region} = LiveResolutionManager.fetch(region_id, manager)

      {region_id,
       Map.take(region.summary, [
         :population,
         :regional_stock,
         :regional_support,
         :local_resource_pressure,
         :last_production,
         :last_consumption
       ])}
    end)
  end

  defp snapshot_metrics(lifecycle, locations) do
    Map.new(locations, fn {identity, region_id} ->
      case DormantMindArchive.fetch(region_id, identity, lifecycle) do
        {:ok, snapshot} ->
          {identity,
           %{
             bytes: :erlang.external_size(snapshot),
             cost: DevelopmentalMindSnapshot.cost(snapshot),
             retained: snapshot.metrics
           }}

        {:error, reason} ->
          {identity, %{error: reason}}
      end
    end)
  end

  defp analyze(traces) do
    decisions = Enum.flat_map(traces, & &1.decisions)
    directions = decisions |> Enum.filter(&(&1[:action] == :continue)) |> Enum.group_by(& &1.identity, & &1.direction)
    reversals = Enum.sum(Enum.map(directions, fn {_id, values} -> count_reversals(values) end))
    repeat_choices = Enum.sum(Enum.map(directions, fn {_id, values} -> count_repeats(values) end))
    {deteriorations, recoveries} = energy_changes(traces)

    %{
      population_changed?: population_changed?(traces),
      cascading_feedback_observed?: cascading_feedback?(traces),
      route_reversals: reversals,
      repeated_direction_choices: repeat_choices,
      boundary_hesitation_ticks: hesitation_ticks(decisions),
      bodily_deteriorations: deteriorations,
      bodily_recoveries: recoveries,
      distinct_regions_entered:
        traces
        |> Enum.flat_map(& &1.location_changes)
        |> Enum.map(& &1.to)
        |> Enum.reject(&match?({:transit, _, _, _}, &1))
        |> Enum.uniq()
        |> length(),
      dynamic_conditions_changed?: dynamic_conditions_changed?(traces)
    }
  end

  defp population_changed?([first | _] = traces) do
    last = List.last(traces)
    Enum.any?(@regions, fn region -> first.regional[region].population != last.regional[region].population end)
  end

  defp population_changed?([]), do: false

  defp cascading_feedback?(traces) do
    traces
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.any?(fn [before, changed, after] ->
      Enum.any?(@regions, fn region ->
        before.regional[region].population != changed.regional[region].population and
          (changed.regional[region].last_production != after.regional[region].last_production or
             changed.regional[region].regional_support != after.regional[region].regional_support)
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

  defp count_reversals(values) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.count(fn [a, b] -> opposite?(a, b) end)
  end

  defp count_repeats(values) do
    values
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.count(fn [a, b] -> a == b end)
  end

  defp opposite?(:east, :west), do: true
  defp opposite?(:west, :east), do: true
  defp opposite?(:north, :south), do: true
  defp opposite?(:south, :north), do: true
  defp opposite?(_, _), do: false

  defp hesitation_ticks(decisions) do
    decisions
    |> Enum.group_by(& &1.identity)
    |> Enum.reduce(0, fn {_identity, values}, total ->
      {sum, streak} =
        Enum.reduce(values, {0, 0}, fn decision, {sum, streak} ->
          case decision[:action] do
            :remain -> {sum, streak + 1}
            :continue -> {sum + streak, 0}
            _ -> {sum, streak}
          end
        end)

      total + sum + streak
    end)
  end

  defp energy_changes(traces) do
    traces
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce({0, 0}, fn [before, after], {down, up} ->
      Enum.reduce(after.commitments, {down, up}, fn {identity, commitment}, {d, u} ->
        previous = get_in(before.commitments, [identity, :energy])
        current = Map.get(commitment, :energy)

        cond do
          is_number(previous) and is_number(current) and current < previous -> {d + 1, u}
          is_number(previous) and is_number(current) and current > previous -> {d, u + 1}
          true -> {d, u}
        end
      end)
    end)
  end

  defp initial_totals,
    do: %{attempted: 0, succeeded: 0, failed: 0, deferred: 0, location_changes: 0, entered_regions: 0}

  defp add_totals(totals, trace) do
    entered = Enum.count(trace.travel_events, &match?({:entered_region, _, _}, &1))

    totals
    |> Map.update!(:attempted, &(&1 + trace.attempted))
    |> Map.update!(:succeeded, &(&1 + trace.succeeded))
    |> Map.update!(:failed, &(&1 + trace.failed))
    |> Map.update!(:deferred, &(&1 + trace.deferred))
    |> Map.update!(:location_changes, &(&1 + length(trace.location_changes)))
    |> Map.update!(:entered_regions, &(&1 + entered))
  end

  defp waiting_count(travel),
    do: travel |> CoarseTravel.trace() |> DormantLocomotionBatch.waiting_identities() |> length()

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
