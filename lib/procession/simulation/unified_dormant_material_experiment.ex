defmodule Procession.Simulation.UnifiedDormantMaterialExperiment do
  @moduledoc """
  Runs a three-region material world where archived developmental minds own every
  gathering, transformation, consumption, transfer, and boundary-crossing attempt.
  """

  alias Procession.Simulation.CognitiveMaterialKernel
  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.DormantMaterialDecision
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle

  @regions [:west_fields, :crossroads, :east_refuge]
  @profiles [
    %{id: "orin", region: :west_fields, position: {0, 0}, energy: 0.76},
    %{id: "lena", region: :west_fields, position: {1, 0}, energy: 0.50},
    %{id: "pavel", region: :west_fields, position: {2, 0}, energy: 0.35},
    %{id: "mara", region: :crossroads, position: {0, 0}, energy: 0.44},
    %{id: "tess", region: :east_refuge, position: {0, 0}, energy: 0.68},
    %{id: "sela", region: :east_refuge, position: {1, 0}, energy: 0.31}
  ]

  def run(opts \\ []) do
    ticks = max(1, Keyword.get(opts, :ticks, 96))
    budget = max(0, Keyword.get(opts, :budget, 3))
    cadence = max(1, Keyword.get(opts, :cadence, 1))
    seed = Keyword.get(opts, :seed, 41)
    world = start_world(seed)
    initial_total = total_material(world.regions)
    started = System.monotonic_time(:microsecond)

    {regions, _cursor, traces} =
      Enum.reduce(1..ticks, {world.regions, 0, []}, fn tick, {regions, cursor, traces} ->
        regions = Map.new(regions, fn {id, kernel} -> {id, CognitiveMaterialKernel.begin_tick(kernel)} end)

        if rem(tick, cadence) == 0 do
          ids = locations(regions) |> Map.keys() |> Enum.sort()
          selected = rotate_take(ids, cursor, budget)

          {regions, decisions} =
            Enum.reduce(selected, {regions, []}, fn identity_id, {current, decisions} ->
              {next, decision} = decide_and_apply(current, identity_id, tick, seed, world)
              {next, [decision | decisions]}
            end)

          trace = trace(tick, regions, Enum.reverse(decisions), length(ids) - length(selected))
          {regions, cursor + budget, [trace | traces]}
        else
          trace = trace(tick, regions, [], map_size(locations(regions)))
          {regions, cursor, [trace | traces]}
        end
      end)

    elapsed = System.monotonic_time(:microsecond) - started
    traces = Enum.reverse(traces)
    result = summarize(regions, traces, initial_total, elapsed, ticks, budget, cadence, seed)
    stop_world(world)
    result
  end

  defp decide_and_apply(regions, identity_id, tick, seed, world) do
    region_id = locations(regions)[identity_id]
    kernel = regions[region_id]
    resident = kernel.residents[identity_id]

    context = %{
      resident: resident,
      loose_raw: kernel.loose_raw,
      pressure: CognitiveMaterialKernel.pressure(kernel),
      contacts: CognitiveMaterialKernel.contacts(kernel, identity_id),
      exits: exits(region_id)
    }

    opts = [
      lifecycle_server: world.lifecycle,
      loop_opts: [seed: seed + :erlang.phash2(identity_id, 10_000), output_exploration: 0.82]
    ]

    case DormantMaterialDecision.begin_cycle(region_id, identity_id, context, tick, opts) do
      {:ok, token} ->
        {regions, consequence, destination_region} =
          execute(regions, region_id, identity_id, token.action, world)

        commit_token =
          if destination_region == region_id,
            do: token,
            else: %{token | region_id: destination_region}

        commit =
          DormantMaterialDecision.commit_cycle(
            commit_token,
            consequence.features,
            consequence.coherence,
            opts
          )

        {regions,
         %{
           identity: identity_id,
           from: region_id,
           to: destination_region,
           primitive: token.action.primitive,
           motor_pattern: token.outcome.pattern,
           motor_direction: token.outcome.direction,
           consequence: consequence.kind,
           amount: consequence.amount,
           moved?: destination_region != region_id,
           commit: commit
         }}

      {:error, reason} ->
        {regions, %{identity: identity_id, from: region_id, error: reason, moved?: false}}
    end
  end

  defp execute(
         regions,
         region_id,
         identity_id,
         %{primitive: :cross_region_boundary, region_id: to},
         world
       ) do
    case RegionActivationLifecycle.migrate(identity_id, region_id, to, [], world.lifecycle) do
      {:ok, _} ->
        {resident, source} = CognitiveMaterialKernel.remove_resident(regions[region_id], identity_id)
        target = CognitiveMaterialKernel.put_resident(regions[to], %{resident | position: {0, 0}})
        next = regions |> Map.put(region_id, source) |> Map.put(to, target)
        {next, physical_consequence(:crossed_region_boundary, 0.0, 0.2), to}

      {:error, _} ->
        {regions, physical_consequence(:boundary_crossing_rejected, 0.0, -0.05), region_id}
    end
  end

  defp execute(regions, region_id, identity_id, action, _world) do
    {kernel, consequence} = CognitiveMaterialKernel.apply(regions[region_id], identity_id, action)
    {Map.put(regions, region_id, kernel), consequence, region_id}
  end

  defp physical_consequence(kind, amount, coherence) do
    %{
      kind: kind,
      amount: amount,
      coherence: coherence,
      features: [{:signal, {:physical_consequence, kind}, 1.0}]
    }
  end

  defp trace(tick, regions, decisions, deferred) do
    %{
      tick: tick,
      populations: Map.new(regions, fn {id, kernel} -> {id, map_size(kernel.residents)} end),
      pressures:
        Map.new(regions, fn {id, kernel} -> {id, CognitiveMaterialKernel.pressure(kernel)} end),
      decisions: decisions,
      deferred: max(0, deferred)
    }
  end

  defp summarize(regions, traces, initial_total, elapsed, ticks, budget, cadence, seed) do
    decisions = Enum.flat_map(traces, & &1.decisions)
    successful = Enum.reject(decisions, &Map.has_key?(&1, :error))
    counts = Enum.frequencies_by(successful, fn decision -> decision.primitive end)
    replenished = ticks * Enum.sum(Enum.map(regions, fn {_id, kernel} -> kernel.replenishment end))

    %{
      experiment: :unified_dormant_material_cognition,
      ticks: ticks,
      budget: budget,
      cadence: cadence,
      seed: seed,
      totals: %{
        decisions: length(decisions),
        failures: length(decisions) - length(successful),
        deferred: Enum.sum(Enum.map(traces, & &1.deferred)),
        migrations: Enum.count(successful, & &1.moved?),
        primitives: counts,
        runtime_us_per_tick: elapsed / ticks
      },
      final_populations:
        Map.new(regions, fn {id, kernel} -> {id, map_size(kernel.residents)} end),
      material_accounting_error: total_material(regions) - (initial_total + replenished),
      analysis: %{
        archived_minds_committed?: Enum.all?(successful, &match?({:ok, _}, &1.commit)),
        material_primitives_observed?:
          Enum.any?(
            successful,
            &(&1.primitive in [
                :contact_loose_raw,
                :manipulate_held_raw,
                :consume_held_usable,
                :contact_body
              ])
          ),
        population_changed?: traces |> Enum.map(& &1.populations) |> Enum.uniq() |> length() > 1,
        pressure_changed?: traces |> Enum.map(& &1.pressures) |> Enum.uniq() |> length() > 1,
        cascade_observed?: cascade?(traces)
      },
      traces: traces
    }
  end

  defp cascade?(traces) do
    traces
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.any?(fn [before, changed, later] ->
      before.populations != changed.populations and changed.pressures != later.pressures
    end)
  end

  defp start_world(seed) do
    suffix = System.unique_integer([:positive, :monotonic])
    manager = String.to_atom("unified_material_manager_#{suffix}")
    lifecycle = String.to_atom("unified_material_lifecycle_#{suffix}")
    {:ok, _} = LiveResolutionManager.start_link(name: manager)
    {:ok, _} = RegionActivationLifecycle.start_link(name: lifecycle, resolution_server: manager)
    regions = seed_regions(manager)
    seed_archives(lifecycle, seed)
    %{manager: manager, lifecycle: lifecycle, regions: regions}
  end

  defp seed_regions(manager) do
    Map.new(@regions, fn region_id ->
      profiles = Enum.filter(@profiles, &(&1.region == region_id))

      residents =
        Enum.map(profiles, fn profile ->
          %{
            id: profile.id,
            position: profile.position,
            energy: profile.energy,
            raw: 0.02,
            usable: 0.05,
            capacity: 0.65,
            gather_rate: 0.05,
            transform_rate: 0.035,
            consume_rate: 0.025,
            transfer_rate: 0.02
          }
        end)

      commitments =
        Map.new(residents, fn resident ->
          {resident.id,
           %{
             position: resident.position,
             energy: resident.energy,
             mobility: 0.85,
             inventory: resident.usable
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

      {:ok, _} = LiveResolutionManager.put(%{region | summary: summary}, manager)

      opts =
        case region_id do
          :west_fields -> [loose_raw: 1.2, replenishment: 0.03]
          :crossroads -> [loose_raw: 0.35, replenishment: 0.006]
          :east_refuge -> [loose_raw: 0.75, replenishment: 0.015]
        end

      {region_id,
       CognitiveMaterialKernel.new(Keyword.merge(opts, residents: residents, contact_radius: 1))}
    end)
  end

  defp seed_archives(lifecycle, seed) do
    snapshots = Map.new(@profiles, fn profile -> {profile.id, fresh_snapshot(profile.id, seed)} end)

    :sys.replace_state(lifecycle, fn state ->
      archives =
        Map.new(@regions, fn region_id ->
          ids = @profiles |> Enum.filter(&(&1.region == region_id)) |> Enum.map(& &1.id)

          {region_id,
           %{
             snapshots: Map.new(ids, &{&1, %{location: region_id}}),
             mind_snapshots: Map.take(snapshots, ids),
             population_minds: nil,
             compressed_at_tick: 0,
             stopped_entity_ids: ids
           }}
        end)

      %{state | archives: archives}
    end)
  end

  defp fresh_snapshot(identity_id, seed) do
    DevelopmentalSensorimotorLoop.new(
      field_opts: [
        micro_nodes: 96,
        input_width: 4,
        encoding_salt: {:unified_material, identity_id}
      ],
      body_opts: [initial_coordination: 0.35],
      seed: seed + :erlang.phash2(identity_id, 10_000)
    )
    |> DevelopmentalMindSnapshot.capture()
  end

  defp exits(:west_fields), do: [%{direction: :east, region_id: :crossroads}]

  defp exits(:crossroads),
    do: [
      %{direction: :west, region_id: :west_fields},
      %{direction: :east, region_id: :east_refuge}
    ]

  defp exits(:east_refuge), do: [%{direction: :west, region_id: :crossroads}]

  defp locations(regions) do
    regions
    |> Enum.flat_map(fn {region_id, kernel} ->
      Enum.map(kernel.residents, fn {id, _} -> {id, region_id} end)
    end)
    |> Map.new()
  end

  defp total_material(regions) do
    Enum.sum(
      Enum.map(regions, fn {_id, kernel} -> CognitiveMaterialKernel.total_material(kernel) end)
    )
  end

  defp rotate_take([], _cursor, _budget), do: []

  defp rotate_take(ids, cursor, budget) do
    ids
    |> Stream.cycle()
    |> Stream.drop(rem(cursor, length(ids)))
    |> Enum.take(min(budget, length(ids)))
  end

  defp stop_world(world) do
    Enum.each([world.lifecycle, world.manager], fn name ->
      if pid = Process.whereis(name), do: GenServer.stop(pid, :normal)
    end)
  end
end
