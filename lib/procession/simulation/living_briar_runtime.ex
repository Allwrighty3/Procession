defmodule Procession.Simulation.LivingBriarRuntime do
  @moduledoc "Stateful owner for the canonical Living Briar simulation."

  use GenServer

  alias Procession.Simulation.CognitiveMaterialKernel
  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.DormantMaterialDecision
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle

  @regions [:west_fields, :crossroads, :east_refuge]
  @persistent_primitives [
    :contact_loose_raw,
    :manipulate_held_raw,
    :consume_held_usable,
    :contact_body,
    :move_local,
    :cross_region_boundary
  ]
  @location_regions %{
    "loc_crossroads" => :crossroads,
    "loc_briar_village" => :west_fields,
    "loc_silent_mine" => :east_refuge
  }
  @profiles [
    %{id: "orin", region: :west_fields, position: {0, 0}, energy: 0.76},
    %{id: "lena", region: :west_fields, position: {1, 0}, energy: 0.50},
    %{id: "pavel", region: :west_fields, position: {2, 0}, energy: 0.35},
    %{id: "mara", region: :crossroads, position: {0, 0}, energy: 0.44},
    %{id: "tess", region: :east_refuge, position: {0, 0}, energy: 0.68},
    %{id: "sela", region: :east_refuge, position: {1, 0}, energy: 0.31}
  ]

  defstruct [
    :manager,
    :lifecycle,
    :regions,
    :seed,
    :budget,
    :cadence,
    :initial_total,
    :player_id,
    :player_location,
    :player_region,
    :player_body,
    tick: 0,
    cursor: 0,
    traces: [],
    failures: 0,
    player_events: [],
    resident_processes: %{},
    resident_process_events: []
  ]

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)
  def step(runtime), do: GenServer.call(runtime, :step, 60_000)
  def snapshot(runtime), do: GenServer.call(runtime, :snapshot)

  def set_player_location(runtime, player_id, location_id),
    do: GenServer.call(runtime, {:set_player_location, player_id, location_id})

  def player_action(runtime, primitive, opts \\ []),
    do: GenServer.call(runtime, {:player_action, primitive, opts})

  def stop(runtime), do: GenServer.stop(runtime, :normal)
  def region_for_location(location_id), do: Map.get(@location_regions, location_id)

  @impl true
  def init(opts) do
    seed = Keyword.get(opts, :seed, 41)
    budget = max(0, Keyword.get(opts, :budget, 3))
    cadence = max(1, Keyword.get(opts, :cadence, 1))
    suffix = System.unique_integer([:positive, :monotonic])
    manager_name = String.to_atom("living_briar_manager_#{suffix}")
    lifecycle_name = String.to_atom("living_briar_lifecycle_#{suffix}")
    {:ok, manager} = LiveResolutionManager.start_link(name: manager_name)

    {:ok, lifecycle} =
      RegionActivationLifecycle.start_link(name: lifecycle_name, resolution_server: manager)

    regions = seed_regions(manager)
    seed_archives(lifecycle, seed)

    {:ok,
     %__MODULE__{
       manager: manager,
       lifecycle: lifecycle,
       regions: regions,
       seed: seed,
       budget: budget,
       cadence: cadence,
       initial_total: total_material(regions)
     }}
  end

  @impl true
  def handle_call({:set_player_location, player_id, location_id}, _from, state) do
    region = region_for_location(location_id)
    body = (state.player_body || default_player_body(player_id)) |> Map.put(:position, {0, 0})

    next = %{
      state
      | player_id: player_id,
        player_location: location_id,
        player_region: region,
        player_body: body
    }

    {:reply, {:ok, player_observation(next)}, next}
  end

  def handle_call({:player_action, primitive, opts}, _from, state) do
    case apply_player_action(state, primitive, opts) do
      {:ok, result, next} -> {:reply, {:ok, result}, next}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:step, _from, state) do
    tick = state.tick + 1

    replenished_regions =
      Map.new(state.regions, fn {id, kernel} ->
        {id, CognitiveMaterialKernel.begin_tick(kernel)}
      end)

    {regions, resident_processes, process_events} =
      advance_resident_processes(replenished_regions, state.resident_processes, tick, state)

    {regions, resident_processes, decisions, deferred, cursor, cognition_process_events} =
      service_cognition(regions, resident_processes, tick, state)

    all_process_events = process_events ++ cognition_process_events
    observed_by = Enum.count(decisions, &(&1[:player_observed?] == true))

    trace =
      trace(
        tick,
        regions,
        decisions,
        deferred,
        state,
        observed_by,
        resident_processes,
        all_process_events
      )

    failures = state.failures + Enum.count(decisions, &Map.has_key?(&1, :error))

    next_state = %{
      state
      | regions: regions,
        tick: tick,
        cursor: cursor,
        traces: [trace | state.traces],
        failures: failures,
        resident_processes: resident_processes,
        resident_process_events:
          Enum.reverse(all_process_events) ++ state.resident_process_events
    }

    {:reply, {:ok, observe_tick(trace, List.first(state.traces))}, next_state}
  end

  def handle_call(:snapshot, _from, state) do
    traces = Enum.reverse(state.traces)
    decisions = Enum.flat_map(traces, & &1.decisions)
    successful = Enum.reject(decisions, &Map.has_key?(&1, :error))

    replenished =
      state.tick *
        Enum.sum(Enum.map(state.regions, fn {_id, kernel} -> kernel.replenishment end))

    process_events = Enum.reverse(state.resident_process_events)

    {:reply,
     %{
       tick: state.tick,
       budget: state.budget,
       cadence: state.cadence,
       seed: state.seed,
       populations: populations(state.regions),
       pressures: pressures(state.regions),
       player_id: state.player_id,
       player_location: state.player_location,
       player_region: state.player_region,
       player_body: state.player_body,
       player_events: Enum.reverse(state.player_events),
       player_observations: Enum.count(decisions, &(&1[:player_observed?] == true)),
       decisions: length(decisions),
       failures: state.failures,
       migrations:
       Enum.count(successful, & &1.moved?) +
         Enum.count(process_events, &(&1.status == :arrived)),
       deferred: Enum.sum(Enum.map(traces, & &1.deferred)),
       primitives: Enum.frequencies_by(successful, & &1.primitive),
       resident_processes: state.resident_processes,
       resident_process_events: process_events,
       resident_process_starts: Enum.count(process_events, &(&1.status == :started)),
       resident_process_redirects: Enum.count(process_events, &(&1.status == :redirected)),
       resident_process_interruptions: Enum.count(process_events, &(&1.status == :interrupted)),
       resident_process_progress: Enum.count(process_events, &(&1.status == :continuing)),
       resident_process_endings: Enum.count(process_events, &(&1.status == :ended)),
       transit_starts:
         Enum.count(process_events, &(&1.primitive == :cross_region_boundary and &1.status == :started)),
       transit_progress:
         Enum.count(process_events, &(&1.primitive == :cross_region_boundary and &1.status == :continuing)),
       transit_arrivals:
         Enum.count(process_events, &(&1.primitive == :cross_region_boundary and &1.status == :arrived)),
       transit_stranded:
         Enum.count(process_events, &(&1.primitive == :cross_region_boundary and &1.status == :stranded)),
       material_accounting_error:
         total_material(state.regions) + transit_material(state.resident_processes) +
           player_material(state.player_body) - (state.initial_total + replenished),
       archived_minds_committed?: Enum.all?(successful, &match?({:ok, _}, &1.commit))
     }, state}
  end

  @impl true
  def terminate(_reason, state) do
    stop_if_alive(state.lifecycle)
    stop_if_alive(state.manager)
    :ok
  end

  defp service_cognition(regions, processes, tick, state) do
    if rem(tick, state.cadence) == 0 do
      ids = locations(regions) |> Map.keys() |> Enum.sort()
      selected = rotate_take(ids, state.cursor, state.budget)

      {next_regions, next_processes, decisions, events} =
        Enum.reduce(selected, {regions, processes, [], []}, fn identity_id,
                                                              {current_regions,
                                                               current_processes,
                                                               current_decisions,
                                                               current_events} ->
          {updated_regions, updated_processes, decision, decision_events} =
            decide_and_apply(current_regions, current_processes, identity_id, tick, state)

          {
            updated_regions,
            updated_processes,
            [decision | current_decisions],
            decision_events ++ current_events
          }
        end)

      {
        next_regions,
        next_processes,
        Enum.reverse(decisions),
        max(0, length(ids) - length(selected)),
        state.cursor + state.budget,
        Enum.reverse(events)
      }
    else
      {regions, processes, [], map_size(locations(regions)), state.cursor, []}
    end
  end

  defp advance_resident_processes(regions, processes, tick, state) do
  processes
  |> Enum.sort_by(fn {identity_id, _process} -> identity_id end)
  |> Enum.reduce({regions, %{}, []}, fn {identity_id, process},
                                      {current_regions, next_processes, events} ->
    if process.primitive == :cross_region_boundary do
      {updated_regions, updated_process, status, consequence} =
        advance_transit_process(current_regions, identity_id, process, state)

      event =
        process_event(
          identity_id,
          updated_process,
          status,
          tick,
          consequence.amount,
          consequence.kind
        )

      next_processes =
        if status in [:continuing, :stranded] do
          Map.put(next_processes, identity_id, updated_process)
        else
          next_processes
        end

      {updated_regions, next_processes, [event | events]}
    else
      case Map.get(locations(current_regions), identity_id) do
        nil ->
          event =
            process_event(identity_id, process, :interrupted, tick, 0.0, :identity_absent)

          {current_regions, next_processes, [event | events]}

        region_id ->
          {updated_regions, consequence} =
            advance_physical_process(current_regions, region_id, identity_id, process)

          accumulated = process.accumulated + consequence.amount
          updated_process = %{process | region_id: region_id, accumulated: accumulated}

          if process_can_continue?(updated_regions, identity_id, updated_process, consequence) do
            event =
              process_event(
                identity_id,
                updated_process,
                :continuing,
                tick,
                consequence.amount,
                consequence.kind
              )

            {
              updated_regions,
              Map.put(next_processes, identity_id, updated_process),
              [event | events]
            }
          else
            event =
              process_event(
                identity_id,
                updated_process,
                :ended,
                tick,
                consequence.amount,
                consequence.kind
              )

            {updated_regions, next_processes, [event | events]}
          end
      end
    end
  end)
  |> then(fn {next_regions, next_processes, events} ->
    {next_regions, next_processes, Enum.reverse(events)}
  end)
end

defp advance_transit_process(regions, identity_id, process, state) do
  source_region = process.region_id
  destination_region = process.action.region_id
  extent = Map.get(process, :extent, transit_extent(source_region, destination_region))

  {body, regions} =
    case Map.get(process, :body) do
      nil ->
        {resident, source} =
          CognitiveMaterialKernel.remove_resident(regions[source_region], identity_id)

        {resident, Map.put(regions, source_region, source)}

      resident ->
        {resident, regions}
    end

  energy = clamp(body.energy - 0.018, 0.0, 1.0)
  body = %{body | energy: energy}
  progress = process.accumulated + if(energy > 0.0, do: 1.0, else: 0.0)

  updated_process =
    process
    |> Map.put(:body, body)
    |> Map.put(:extent, extent)
    |> Map.put(:accumulated, progress)

  cond do
    energy <= 0.0 and progress < extent ->
      {regions, updated_process, :stranded,
       physical_consequence(:transit_stranded, 0.0, -0.2)}

    progress < extent ->
      {regions, updated_process, :continuing,
       physical_consequence(:advanced_in_transit, 1.0, 0.1)}

    true ->
      case RegionActivationLifecycle.migrate(
             identity_id,
             source_region,
             destination_region,
             [],
             state.lifecycle
           ) do
        {:ok, _} ->
          target =
            CognitiveMaterialKernel.put_resident(
              regions[destination_region],
              %{body | position: transit_entry_position(process.action.direction)}
            )

          {Map.put(regions, destination_region, target), updated_process, :arrived,
           physical_consequence(:crossed_region_boundary, 1.0, 0.2)}

        {:error, _} ->
          source = CognitiveMaterialKernel.put_resident(regions[source_region], body)

          {Map.put(regions, source_region, source), updated_process, :ended,
           physical_consequence(:boundary_crossing_rejected, 0.0, -0.1)}
      end
  end
end

  defp advance_physical_process(regions, region_id, identity_id, %{primitive: :move_local} = process) do
    kernel = regions[region_id]
    resident = kernel.residents[identity_id]

    case local_target_position(kernel, region_id, process.action) do
      nil ->
        {regions, physical_consequence(:local_target_absent, 0.0, -0.05)}

      target_position ->
        next_position = step_toward(resident.position, target_position)
        moved = if next_position == resident.position, do: 0.0, else: 1.0
        resident = %{resident | position: next_position}
        kernel = %{kernel | residents: Map.put(kernel.residents, identity_id, resident)}
        {Map.put(regions, region_id, kernel), physical_consequence(:moved_locally, moved, 0.12)}
    end
  end

  defp advance_physical_process(
         regions,
         region_id,
         identity_id,
         %{primitive: :contact_loose_raw}
       ) do
    kernel = regions[region_id]
    resident = kernel.residents[identity_id]

    if distance(resident.position, raw_position(region_id)) <= kernel.contact_radius do
      {next_kernel, consequence} =
        CognitiveMaterialKernel.apply(kernel, identity_id, %{primitive: :contact_loose_raw})

      {Map.put(regions, region_id, next_kernel), consequence}
    else
      {regions, physical_consequence(:loose_raw_out_of_contact, 0.0, -0.05)}
    end
  end

  defp advance_physical_process(regions, region_id, identity_id, process) do
    {kernel, consequence} =
      CognitiveMaterialKernel.apply(regions[region_id], identity_id, process.action)

    {Map.put(regions, region_id, kernel), consequence}
  end

  defp process_can_continue?(_regions, _identity_id, _process, %{amount: amount})
       when amount <= 1.0e-12,
       do: false

  defp process_can_continue?(regions, identity_id, process, _consequence) do
    region_id = Map.get(locations(regions), identity_id)
    kernel = region_id && regions[region_id]
    resident = kernel && kernel.residents[identity_id]

    case {process.primitive, kernel, resident} do
      {:move_local, %{} = material, %{} = body} ->
        case local_target_position(material, region_id, process.action) do
          nil -> false
          target -> distance(body.position, target) > material.contact_radius
        end

      {:contact_loose_raw, %{} = material, %{} = body} ->
        room = max(0.0, body.capacity - body.raw - body.usable)

        distance(body.position, raw_position(region_id)) <= material.contact_radius and
          material.loose_raw > 1.0e-12 and room > 1.0e-12 and body.gather_rate > 0.0

      {:manipulate_held_raw, _material, %{} = body} ->
        body.raw > 1.0e-12 and body.transform_rate > 0.0

      {:consume_held_usable, _material, %{} = body} ->
        body.usable > 1.0e-12 and body.consume_rate > 0.0

      {:contact_body, %{} = material, %{} = body} ->
        target_id = process.action.counterparty_id

        case Map.get(material.residents, target_id) do
          nil ->
            false

          target ->
            room = max(0.0, target.capacity - target.raw - target.usable)

            distance(body.position, target.position) <= material.contact_radius and
              body.usable > 1.0e-12 and room > 1.0e-12 and body.transfer_rate > 0.0
        end

      _ ->
        false
    end
  end

  defp apply_player_action(%{player_region: nil}, _primitive, _opts),
    do: {:error, :player_not_in_living_region}

  defp apply_player_action(state, :move, opts) do
    direction = Keyword.get(opts, :direction)

    case direction_delta(direction) do
      nil ->
        {:error, :invalid_direction}

      {dx, dy} ->
        {x, y} = state.player_body.position
        body = %{state.player_body | position: {x + dx, y + dy}}
        event = player_event(:moved, %{direction: direction, position: body.position})
        {:ok, event, record_player_event(%{state | player_body: body}, event)}
    end
  end

  defp apply_player_action(state, :contact_loose_raw, _opts) do
    kernel = Map.fetch!(state.regions, state.player_region)
    body = state.player_body
    room = max(0.0, body.capacity - body.raw - body.usable)
    amount = min(kernel.loose_raw, min(body.gather_rate, room))
    next_kernel = %{kernel | loose_raw: kernel.loose_raw - amount}
    body = %{body | raw: body.raw + amount}
    event = player_event(:gathered_raw, %{amount: amount})

    next = %{
      state
      | regions: Map.put(state.regions, state.player_region, next_kernel),
        player_body: body
    }

    {:ok, event, record_player_event(next, event)}
  end

  defp apply_player_action(state, :manipulate_held_raw, _opts) do
    body = state.player_body
    amount = min(body.raw, body.transform_rate)
    body = %{body | raw: body.raw - amount, usable: body.usable + amount}
    event = player_event(:transformed_material, %{amount: amount})
    {:ok, event, record_player_event(%{state | player_body: body}, event)}
  end

  defp apply_player_action(state, :consume_held_usable, _opts) do
    body = state.player_body
    demand = body.consume_rate + max(0.0, 0.5 - body.energy) * 0.03
    amount = min(body.usable, demand)
    energy = clamp(body.energy - 0.012 + amount * 1.8, 0.0, 1.0)

    body = %{
      body
      | usable: body.usable - amount,
        energy: energy,
        consumed: body.consumed + amount
    }

    event = player_event(:consumed_usable, %{amount: amount, energy: energy})
    {:ok, event, record_player_event(%{state | player_body: body}, event)}
  end

  defp apply_player_action(state, :contact_body, opts) do
    target_id = Keyword.get(opts, :target_id)
    kernel = Map.fetch!(state.regions, state.player_region)

    with %{} = target <- Map.get(kernel.residents, target_id),
         true <- distance(state.player_body.position, target.position) <= kernel.contact_radius do
      body = state.player_body
      room = max(0.0, target.capacity - target.raw - target.usable)
      amount = min(body.transfer_rate, min(body.usable, room))
      body = %{body | usable: body.usable - amount}
      target = %{target | usable: target.usable + amount}
      kernel = %{kernel | residents: Map.put(kernel.residents, target_id, target)}
      event = player_event(:transferred_usable, %{amount: amount, target_id: target_id})

      next = %{
        state
        | regions: Map.put(state.regions, state.player_region, kernel),
          player_body: body
      }

      {:ok, event, record_player_event(next, event)}
    else
      nil -> {:error, :unknown_regional_body}
      false -> {:error, :body_out_of_contact}
    end
  end

  defp apply_player_action(_state, _primitive, _opts), do: {:error, :invalid_player_primitive}

  defp decide_and_apply(regions, processes, identity_id, tick, state) do
    region_id = locations(regions)[identity_id]
    kernel = regions[region_id]
    resident = kernel.residents[identity_id]
    observed_bodies = player_observation(state, region_id, resident)
    resource_position = raw_position(region_id)

    context = %{
      resident: resident,
      loose_raw: kernel.loose_raw,
      loose_raw_direction: relative_direction(resident.position, resource_position),
      loose_raw_distance: distance(resident.position, resource_position),
      loose_raw_contact?:
        distance(resident.position, resource_position) <= kernel.contact_radius,
      pressure: CognitiveMaterialKernel.pressure(kernel),
      contacts: CognitiveMaterialKernel.contacts(kernel, identity_id),
      observed_bodies: observed_bodies,
      exits: exits(region_id)
    }

    opts = [
      lifecycle_server: state.lifecycle,
      loop_opts: [
        seed: state.seed + :erlang.phash2(identity_id, 10_000),
        output_exploration: 0.82
      ]
    ]

    case DormantMaterialDecision.begin_cycle(region_id, identity_id, context, tick, opts) do
      {:ok, token} ->
        apply_dormant_decision(
          regions,
          processes,
          identity_id,
          region_id,
          tick,
          token,
          opts,
          observed_bodies,
          state
        )

      {:error, reason} ->
        {
          regions,
          processes,
          %{
            identity: identity_id,
            from: region_id,
            error: reason,
            moved?: false,
            player_observed?: observed_bodies != []
          },
          []
        }
    end
  end

  defp apply_dormant_decision(
         regions,
         processes,
         identity_id,
         region_id,
         tick,
         token,
         opts,
         observed_bodies,
         state
       ) do
    action = token.action

    if action.primitive in @persistent_primitives do
      {next_processes, status, process_events} =
        put_resident_process(processes, identity_id, region_id, action, tick)

      consequence = physical_consequence(:physical_process_selected, 0.0, 0.1)
      commit = DormantMaterialDecision.commit_cycle(token, consequence.features, consequence.coherence, opts)

      decision = %{
        identity: identity_id,
        from: region_id,
        to: region_id,
        primitive: action.primitive,
        motor_pattern: token.outcome.pattern,
        motor_direction: token.outcome.direction,
        consequence: consequence.kind,
        amount: 0.0,
        moved?: false,
        process_status: status,
        player_observed?: observed_bodies != [],
        commit: commit
      }

      {regions, next_processes, decision, process_events}
    else
      {remaining_processes, interruption_events} =
        interrupt_resident_process(processes, identity_id, tick)

      {next_regions, consequence, destination_region} =
        execute(regions, region_id, identity_id, action, state)

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

      decision = %{
        identity: identity_id,
        from: region_id,
        to: destination_region,
        primitive: action.primitive,
        motor_pattern: token.outcome.pattern,
        motor_direction: token.outcome.direction,
        consequence: consequence.kind,
        amount: consequence.amount,
        moved?: destination_region != region_id,
        process_status: if(interruption_events == [], do: :none, else: :interrupted),
        player_observed?: observed_bodies != [],
        commit: commit
      }

      {next_regions, remaining_processes, decision, interruption_events}
    end
  end

  defp put_resident_process(processes, identity_id, region_id, action, tick) do
    next = %{
      primitive: action.primitive,
      action: action,
      region_id: region_id,
      started_tick: tick,
      accumulated: 0.0
    }

    case Map.get(processes, identity_id) do
      nil ->
        event = process_event(identity_id, next, :started, tick, 0.0, :cognitive_selection)
        {Map.put(processes, identity_id, next), :started, [event]}

      %{primitive: primitive, action: existing_action}
      when primitive == action.primitive and existing_action == action ->
        {processes, :continued, []}

      existing ->
        interrupted =
          process_event(identity_id, existing, :interrupted, tick, 0.0, :cognitive_redirection)

        redirected =
          process_event(identity_id, next, :redirected, tick, 0.0, :cognitive_selection)

        {Map.put(processes, identity_id, next), :redirected, [interrupted, redirected]}
    end
  end

  defp interrupt_resident_process(processes, identity_id, tick) do
    case Map.pop(processes, identity_id) do
      {nil, next} ->
        {next, []}

      {process, next} ->
        event = process_event(identity_id, process, :interrupted, tick, 0.0, :new_motor_output)
        {next, [event]}
    end
  end

  defp player_observation(
         %{player_id: player_id, player_region: region_id, player_body: player_body},
         region_id,
         resident
       )
       when is_binary(player_id) and is_map(player_body) do
    body_distance = distance(resident.position, player_body.position)

    if body_distance <= 3 do
      [
        %{
          identity_id: player_id,
          direction: relative_direction(resident.position, player_body.position),
          distance: body_distance
        }
      ]
    else
      []
    end
  end

  defp player_observation(_state, _region_id, _resident), do: []

  defp execute(regions, region_id, identity_id, action, _state) do
    {kernel, consequence} = CognitiveMaterialKernel.apply(regions[region_id], identity_id, action)
    {Map.put(regions, region_id, kernel), consequence, region_id}
  end

  defp physical_consequence(kind, amount, coherence),
    do: %{
      kind: kind,
      amount: amount,
      coherence: coherence,
      features: [{:signal, {:physical_consequence, kind}, 1.0}]
    }

  defp process_event(identity_id, process, status, tick, amount, consequence) do
  %{
    identity: identity_id,
    primitive: process.primitive,
    region: process.region_id,
    destination_region: get_in(process, [:action, :region_id]),
    status: status,
    tick: tick,
    amount: amount,
    accumulated: process.accumulated,
    extent: Map.get(process, :extent),
    energy: get_in(process, [:body, :energy]),
    consequence: consequence
  }
end

  defp trace(
         tick,
         regions,
         decisions,
         deferred,
         state,
         observed_by,
         resident_processes,
         resident_process_events
       ),
       do: %{
         tick: tick,
         populations: populations(regions),
         pressures: pressures(regions),
         decisions: decisions,
         deferred: deferred,
         player_region: state.player_region,
         player_location: state.player_location,
         player_position: player_position(state.player_body),
         player_observed_by: observed_by,
         resident_processes: resident_processes,
         resident_process_events: resident_process_events
       }

  defp observe_tick(trace, previous) do
    %{
      tick: trace.tick,
      populations: trace.populations,
      pressures: trace.pressures,
      deferred: trace.deferred,
      player_region: trace.player_region,
      player_location: trace.player_location,
      player_position: trace.player_position,
      player_observed_by: trace.player_observed_by,
      population_changed?: previous != nil and previous.populations != trace.populations,
      resident_processes: trace.resident_processes,
      resident_process_events: trace.resident_process_events,
      decisions: Enum.map(trace.decisions, &observe_decision/1)
    }
  end

  defp observe_decision(%{error: reason} = decision),
    do: %{
      identity: decision.identity,
      region: decision.from,
      result: :failed,
      reason: reason,
      moved?: false,
      player_observed?: decision.player_observed?
    }

  defp observe_decision(decision),
    do: %{
      identity: decision.identity,
      region: decision.from,
      destination_region: decision.to,
      primitive: decision.primitive,
      physical_consequence: decision.consequence,
      amount: decision.amount,
      motor_pattern: decision.motor_pattern,
      observed_direction: decision.motor_direction,
      moved?: decision.moved?,
      process_status: decision.process_status,
      player_observed?: decision.player_observed?,
      mind_committed?: match?({:ok, _}, decision.commit)
    }

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
       CognitiveMaterialKernel.new(
         Keyword.merge(opts, residents: residents, contact_radius: 1)
       )}
    end)
  end

  defp seed_archives(lifecycle, seed) do
    snapshots =
      Map.new(@profiles, fn profile ->
        {profile.id, fresh_snapshot(profile.id, seed)}
      end)

    :sys.replace_state(lifecycle, fn state ->
      archives =
        Map.new(@regions, fn region_id ->
          ids =
            @profiles
            |> Enum.filter(&(&1.region == region_id))
            |> Enum.map(& &1.id)

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
        encoding_salt: {:living_briar, identity_id}
      ],
      body_opts: [initial_coordination: 0.35],
      seed: seed + :erlang.phash2(identity_id, 10_000)
    )
    |> DevelopmentalMindSnapshot.capture()
  end

  defp local_target_position(_kernel, region_id, %{target: :loose_raw}),
    do: raw_position(region_id)

  defp local_target_position(kernel, _region_id, %{counterparty_id: target_id}) do
    case Map.get(kernel.residents, target_id) do
      nil -> nil
      target -> target.position
    end
  end

  defp local_target_position(_kernel, _region_id, _action), do: nil

  defp raw_position(:west_fields), do: {0, -3}
  defp raw_position(:crossroads), do: {0, -3}
  defp raw_position(:east_refuge), do: {0, -3}

  defp step_toward({x, y}, {tx, _ty}) when x < tx, do: {x + 1, y}
  defp step_toward({x, y}, {tx, _ty}) when x > tx, do: {x - 1, y}
  defp step_toward({x, y}, {_tx, ty}) when y < ty, do: {x, y + 1}
  defp step_toward({x, y}, {_tx, ty}) when y > ty, do: {x, y - 1}
  defp step_toward(position, _target), do: position

  defp default_player_body(player_id),
    do: %{
      id: player_id,
      position: {0, 0},
      raw: 0.0,
      usable: 0.0,
      consumed: 0.0,
      energy: 0.7,
      capacity: 0.8,
      gather_rate: 0.06,
      transform_rate: 0.04,
      consume_rate: 0.025,
      transfer_rate: 0.02
    }

  defp player_event(kind, details), do: Map.merge(%{kind: kind}, details)

  defp record_player_event(state, event),
    do: %{state | player_events: [event | state.player_events]}

  defp player_observation(state),
    do: %{
      player_id: state.player_id,
      location: state.player_location,
      region: state.player_region,
      body: state.player_body
    }

  defp player_position(nil), do: nil
  defp player_position(body), do: body.position
  defp player_material(nil), do: 0.0
  defp player_material(body), do: body.raw + body.usable + body.consumed

  defp transit_material(processes) do
    processes
    |> Map.values()
    |> Enum.map(fn process ->
      case Map.get(process, :body) do
        nil -> 0.0
        body -> body.raw + body.usable
      end
    end)
    |> Enum.sum()
  end

  defp transit_extent(:west_fields, :crossroads), do: 3.0
  defp transit_extent(:crossroads, :west_fields), do: 3.0
  defp transit_extent(:crossroads, :east_refuge), do: 4.0
  defp transit_extent(:east_refuge, :crossroads), do: 4.0
  defp transit_extent(_from, _to), do: 3.0
  defp transit_entry_position(:east), do: {-2, 0}
  defp transit_entry_position(:west), do: {2, 0}
  defp transit_entry_position(_), do: {0, 0}
  defp direction_delta(:north), do: {0, -1}
  defp direction_delta(:south), do: {0, 1}
  defp direction_delta(:east), do: {1, 0}
  defp direction_delta(:west), do: {-1, 0}
  defp direction_delta(_), do: nil
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

  defp populations(regions),
    do: Map.new(regions, fn {id, kernel} -> {id, map_size(kernel.residents)} end)

  defp pressures(regions),
    do: Map.new(regions, fn {id, kernel} ->
      {id, CognitiveMaterialKernel.pressure(kernel)}
    end)

  defp rotate_take(_ids, _cursor, budget) when budget <= 0, do: []
  defp rotate_take([], _cursor, _budget), do: []

  defp rotate_take(ids, cursor, budget) do
    count = length(ids)
    offset = rem(cursor, count)
    rotated = Enum.drop(ids, offset) ++ Enum.take(ids, offset)
    Enum.take(rotated, min(budget, count))
  end

  defp total_material(regions),
    do:
      Enum.sum(
        Enum.map(regions, fn {_id, kernel} ->
          CognitiveMaterialKernel.total_material(kernel)
        end)
      )

  defp distance({ax, ay}, {bx, by}), do: abs(ax - bx) + abs(ay - by)

  defp relative_direction({ax, ay}, {bx, by}) do
    dx = bx - ax
    dy = by - ay

    cond do
      abs(dx) >= abs(dy) and dx > 0 -> :east
      abs(dx) >= abs(dy) and dx < 0 -> :west
      dy > 0 -> :south
      dy < 0 -> :north
      true -> :none
    end
  end

  defp clamp(value, low, high), do: value |> max(low) |> min(high)

  defp stop_if_alive(pid) when is_pid(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid, :normal)
  catch
    :exit, _ -> :ok
  end
end
