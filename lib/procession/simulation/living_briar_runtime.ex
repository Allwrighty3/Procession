defmodule Procession.Simulation.LivingBriarRuntime do
  @moduledoc """
  Stateful owner for the canonical Living Briar simulation.

  Regional material kernels and dormant developmental archives remain alive between `step/1`
  calls, so session waits advance one continuous world rather than replaying an experiment.
  """

  use GenServer

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

  defstruct [:manager, :lifecycle, :regions, :seed, :budget, :cadence, :initial_total,
    tick: 0, cursor: 0, traces: [], failures: 0]

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)
  def step(runtime), do: GenServer.call(runtime, :step, 60_000)
  def snapshot(runtime), do: GenServer.call(runtime, :snapshot)
  def stop(runtime), do: GenServer.stop(runtime, :normal)

  @impl true
  def init(opts) do
    seed = Keyword.get(opts, :seed, 41)
    budget = max(0, Keyword.get(opts, :budget, 3))
    cadence = max(1, Keyword.get(opts, :cadence, 1))
    {:ok, manager} = LiveResolutionManager.start_link()
    {:ok, lifecycle} = RegionActivationLifecycle.start_link(resolution_server: manager)
    regions = seed_regions(manager)
    seed_archives(lifecycle, seed)

    {:ok, %__MODULE__{manager: manager, lifecycle: lifecycle, regions: regions, seed: seed,
      budget: budget, cadence: cadence, initial_total: total_material(regions)}}
  end

  @impl true
  def handle_call(:step, _from, state) do
    tick = state.tick + 1
    regions = Map.new(state.regions, fn {id, kernel} -> {id, CognitiveMaterialKernel.begin_tick(kernel)} end)

    {regions, decisions, deferred, cursor} =
      if rem(tick, state.cadence) == 0 do
        ids = locations(regions) |> Map.keys() |> Enum.sort()
        selected = rotate_take(ids, state.cursor, state.budget)
        {next_regions, next_decisions} =
          Enum.reduce(selected, {regions, []}, fn identity_id, {current, decisions} ->
            {next, decision} = decide_and_apply(current, identity_id, tick, state)
            {next, [decision | decisions]}
          end)

        {next_regions, Enum.reverse(next_decisions), max(0, length(ids) - length(selected)),
         state.cursor + state.budget}
      else
        {regions, [], map_size(locations(regions)), state.cursor}
      end

    trace = trace(tick, regions, decisions, deferred)
    failures = state.failures + Enum.count(decisions, &Map.has_key?(&1, :error))
    next_state = %{state | regions: regions, tick: tick, cursor: cursor,
      traces: [trace | state.traces], failures: failures}

    {:reply, {:ok, observe_tick(trace, List.first(state.traces))}, next_state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    traces = Enum.reverse(state.traces)
    decisions = Enum.flat_map(traces, & &1.decisions)
    successful = Enum.reject(decisions, &Map.has_key?(&1, :error))
    replenished = state.tick * Enum.sum(Enum.map(state.regions, fn {_id, kernel} -> kernel.replenishment end))

    {:reply,
     %{tick: state.tick, budget: state.budget, cadence: state.cadence, seed: state.seed,
       populations: populations(state.regions), pressures: pressures(state.regions),
       decisions: length(decisions), failures: state.failures,
       migrations: Enum.count(successful, & &1.moved?),
       deferred: Enum.sum(Enum.map(traces, & &1.deferred)),
       primitives: Enum.frequencies_by(successful, & &1.primitive),
       material_accounting_error: total_material(state.regions) - (state.initial_total + replenished),
       archived_minds_committed?: Enum.all?(successful, &match?({:ok, _}, &1.commit))}, state}
  end

  @impl true
  def terminate(_reason, state) do
    stop_if_alive(state.lifecycle)
    stop_if_alive(state.manager)
    :ok
  end

  defp decide_and_apply(regions, identity_id, tick, state) do
    region_id = locations(regions)[identity_id]
    kernel = regions[region_id]
    resident = kernel.residents[identity_id]
    context = %{resident: resident, loose_raw: kernel.loose_raw,
      pressure: CognitiveMaterialKernel.pressure(kernel),
      contacts: CognitiveMaterialKernel.contacts(kernel, identity_id), exits: exits(region_id)}
    opts = [lifecycle_server: state.lifecycle,
      loop_opts: [seed: state.seed + :erlang.phash2(identity_id, 10_000), output_exploration: 0.82]]

    case DormantMaterialDecision.begin_cycle(region_id, identity_id, context, tick, opts) do
      {:ok, token} ->
        {regions, consequence, destination_region} = execute(regions, region_id, identity_id, token.action, state)
        commit_token = if destination_region == region_id, do: token, else: %{token | region_id: destination_region}
        commit = DormantMaterialDecision.commit_cycle(commit_token, consequence.features, consequence.coherence, opts)
        {regions, %{identity: identity_id, from: region_id, to: destination_region,
          primitive: token.action.primitive, motor_pattern: token.outcome.pattern,
          motor_direction: token.outcome.direction, consequence: consequence.kind,
          amount: consequence.amount, moved?: destination_region != region_id, commit: commit}}

      {:error, reason} ->
        {regions, %{identity: identity_id, from: region_id, error: reason, moved?: false}}
    end
  end

  defp execute(regions, region_id, identity_id,
         %{primitive: :cross_region_boundary, region_id: to}, state) do
    case RegionActivationLifecycle.migrate(identity_id, region_id, to, [], state.lifecycle) do
      {:ok, _} ->
        {resident, source} = CognitiveMaterialKernel.remove_resident(regions[region_id], identity_id)
        target = CognitiveMaterialKernel.put_resident(regions[to], %{resident | position: {0, 0}})
        next = regions |> Map.put(region_id, source) |> Map.put(to, target)
        {next, physical_consequence(:crossed_region_boundary, 0.0, 0.2), to}
      {:error, _} ->
        {regions, physical_consequence(:boundary_crossing_rejected, 0.0, -0.05), region_id}
    end
  end

  defp execute(regions, region_id, identity_id, action, _state) do
    {kernel, consequence} = CognitiveMaterialKernel.apply(regions[region_id], identity_id, action)
    {Map.put(regions, region_id, kernel), consequence, region_id}
  end

  defp physical_consequence(kind, amount, coherence), do:
    %{kind: kind, amount: amount, coherence: coherence,
      features: [{:signal, {:physical_consequence, kind}, 1.0}]}

  defp trace(tick, regions, decisions, deferred), do:
    %{tick: tick, populations: populations(regions), pressures: pressures(regions),
      decisions: decisions, deferred: deferred}

  defp observe_tick(trace, previous) do
    %{tick: trace.tick, populations: trace.populations, pressures: trace.pressures,
      deferred: trace.deferred,
      population_changed?: previous != nil and previous.populations != trace.populations,
      decisions: Enum.map(trace.decisions, &observe_decision/1)}
  end

  defp observe_decision(%{error: reason} = decision), do:
    %{identity: decision.identity, region: decision.from, result: :failed,
      reason: reason, moved?: false}

  defp observe_decision(decision), do:
    %{identity: decision.identity, region: decision.from,
      destination_region: decision.to, primitive: decision.primitive,
      physical_consequence: decision.consequence, amount: decision.amount,
      motor_pattern: decision.motor_pattern, observed_direction: decision.motor_direction,
      moved?: decision.moved?, mind_committed?: match?({:ok, _}, decision.commit)}

  defp seed_regions(manager) do
    Map.new(@regions, fn region_id ->
      profiles = Enum.filter(@profiles, &(&1.region == region_id))
      residents = Enum.map(profiles, fn profile ->
        %{id: profile.id, position: profile.position, energy: profile.energy,
          raw: 0.02, usable: 0.05, capacity: 0.65, gather_rate: 0.05,
          transform_rate: 0.035, consume_rate: 0.025, transfer_rate: 0.02}
      end)
      commitments = Map.new(residents, fn resident ->
        {resident.id, %{position: resident.position, energy: resident.energy,
          mobility: 0.85, inventory: resident.usable}}
      end)
      region = MultiResolutionRegion.new(id: region_id, entities: [])
        |> MultiResolutionRegion.compress() |> MultiResolutionRegion.make_inert()
      summary = region.summary |> Map.put(:identity_anchors, Enum.map(residents, & &1.id))
        |> Map.put(:identity_commitments, commitments) |> Map.put(:population, length(residents))
      {:ok, _} = LiveResolutionManager.put(%{region | summary: summary}, manager)
      opts = case region_id do
        :west_fields -> [loose_raw: 1.2, replenishment: 0.03]
        :crossroads -> [loose_raw: 0.35, replenishment: 0.006]
        :east_refuge -> [loose_raw: 0.75, replenishment: 0.015]
      end
      {region_id, CognitiveMaterialKernel.new(Keyword.merge(opts, residents: residents, contact_radius: 1))}
    end)
  end

  defp seed_archives(lifecycle, seed) do
    snapshots = Map.new(@profiles, fn profile -> {profile.id, fresh_snapshot(profile.id, seed)} end)
    :sys.replace_state(lifecycle, fn state ->
      archives = Map.new(@regions, fn region_id ->
        ids = @profiles |> Enum.filter(&(&1.region == region_id)) |> Enum.map(& &1.id)
        {region_id, %{snapshots: Map.new(ids, &{&1, %{location: region_id}}),
          mind_snapshots: Map.take(snapshots, ids), population_minds: nil,
          compressed_at_tick: 0, stopped_entity_ids: ids}}
      end)
      %{state | archives: archives}
    end)
  end

  defp fresh_snapshot(identity_id, seed) do
    DevelopmentalSensorimotorLoop.new(
      field_opts: [micro_nodes: 96, input_width: 4,
        encoding_salt: {:living_briar, identity_id}],
      body_opts: [initial_coordination: 0.35],
      seed: seed + :erlang.phash2(identity_id, 10_000))
    |> DevelopmentalMindSnapshot.capture()
  end

  defp exits(:west_fields), do: [%{direction: :east, region_id: :crossroads}]
  defp exits(:crossroads), do: [%{direction: :west, region_id: :west_fields},
    %{direction: :east, region_id: :east_refuge}]
  defp exits(:east_refuge), do: [%{direction: :west, region_id: :crossroads}]

  defp locations(regions), do: regions
    |> Enum.flat_map(fn {region_id, kernel} ->
      Enum.map(kernel.residents, fn {id, _} -> {id, region_id} end)
    end) |> Map.new()
  defp populations(regions), do: Map.new(regions, fn {id, kernel} -> {id, map_size(kernel.residents)} end)
  defp pressures(regions), do: Map.new(regions, fn {id, kernel} -> {id, CognitiveMaterialKernel.pressure(kernel)} end)
  defp rotate_take(_ids, _cursor, budget) when budget <= 0, do: []
  defp rotate_take([], _cursor, _budget), do: []
  defp rotate_take(ids, cursor, budget) do
    count = length(ids)
    offset = rem(cursor, count)
    rotated = Enum.drop(ids, offset) ++ Enum.take(ids, offset)
    Enum.take(rotated, min(budget, count))
  end
  defp total_material(regions), do: Enum.sum(Enum.map(regions, fn {_id, kernel} ->
    CognitiveMaterialKernel.total_material(kernel)
  end))
  defp stop_if_alive(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)
  catch
    :exit, _ -> :ok
  end
end
