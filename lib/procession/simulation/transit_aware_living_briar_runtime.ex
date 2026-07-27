defmodule Procession.Simulation.TransitAwareLivingBriarRuntime do
  @moduledoc """
  Owns a `LivingBriarRuntime` while giving bodies between regions their own bounded
  physical and cognitive pass.

  Regional material state and dormant archives remain authoritative in the wrapped runtime.
  Transit cognition emits opaque motor impulses. This coordinator projects those impulses onto
  route geometry, advances velocity and position through world time, and reports arrival,
  stopping, reversal, and return as observations rather than cognitive actions.
  """

  use GenServer

  alias Procession.Simulation.CognitiveMaterialKernel
  alias Procession.Simulation.InTransitDecision
  alias Procession.Simulation.LivingBriarRuntime
  alias Procession.Simulation.RegionActivationLifecycle

  @velocity_epsilon 1.0e-6
  @drag 0.72
  @lateral_drag 0.62
  @energy_per_distance 0.006

  defstruct [:runtime, :seed, :budget, :cadence, cursor: 0, decisions: [], events: []]

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)
  def step(runtime), do: GenServer.call(runtime, :step, 60_000)
  def snapshot(runtime), do: GenServer.call(runtime, :snapshot)

  def set_player_location(runtime, player_id, location_id),
    do: GenServer.call(runtime, {:set_player_location, player_id, location_id})

  def player_action(runtime, primitive, opts \\ []),
    do: GenServer.call(runtime, {:player_action, primitive, opts})

  def stop(runtime), do: GenServer.stop(runtime, :normal)
  def region_for_location(location_id), do: LivingBriarRuntime.region_for_location(location_id)

  @impl true
  def init(opts) do
    with {:ok, runtime} <- LivingBriarRuntime.start_link(opts) do
      {:ok,
       %__MODULE__{
         runtime: runtime,
         seed: Keyword.get(opts, :seed, 41),
         budget: max(0, Keyword.get(opts, :transit_budget, 1)),
         cadence: max(1, Keyword.get(opts, :transit_cadence, 1))
       }}
    end
  end

  @impl true
  def handle_call({:set_player_location, player_id, location_id}, _from, state) do
    {:reply, LivingBriarRuntime.set_player_location(state.runtime, player_id, location_id), state}
  end

  def handle_call({:player_action, primitive, opts}, _from, state) do
    {:reply, LivingBriarRuntime.player_action(state.runtime, primitive, opts), state}
  end

  def handle_call(:step, _from, state) do
    transit = detach_transit(state.runtime)

    with {:ok, regional_observation} <- LivingBriarRuntime.step(state.runtime) do
      tick = regional_observation.tick
      {next_transit, physical_events} = advance_transit(state.runtime, transit, tick)

      {next_transit, decisions, next_cursor} =
        service_transit_cognition(state.runtime, next_transit, tick, state)

      attach_transit_evidence(state.runtime, next_transit, physical_events, decisions)
      snapshot = LivingBriarRuntime.snapshot(state.runtime)

      observation =
        regional_observation
        |> Map.put(:populations, snapshot.populations)
        |> Map.put(:pressures, snapshot.pressures)
        |> Map.put(:resident_processes, snapshot.resident_processes)
        |> Map.update(:resident_process_events, physical_events, &(&1 ++ physical_events))
        |> Map.update(:decisions, Enum.map(decisions, &observe_decision/1), fn existing ->
          existing ++ Enum.map(decisions, &observe_decision/1)
        end)
        |> Map.put(:in_transit_decisions, length(decisions))

      next = %{
        state
        | cursor: next_cursor,
          decisions: Enum.reverse(decisions) ++ state.decisions,
          events: Enum.reverse(physical_events) ++ state.events
      }

      {:reply, {:ok, observation}, next}
    else
      {:error, reason} ->
        reattach_transit(state.runtime, transit)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:snapshot, _from, state) do
    summary = LivingBriarRuntime.snapshot(state.runtime)
    decisions = Enum.reverse(state.decisions)
    successful = Enum.reject(decisions, &Map.has_key?(&1, :error))
    events = Enum.reverse(state.events)

    enhanced =
      summary
      |> Map.put(:in_transit_decisions, length(decisions))
      |> Map.put(:transit_cognitive_primitives, Enum.frequencies_by(successful, & &1.primitive))
      |> Map.put(:transit_stationary_ticks, Enum.count(events, &(&1.status == :stationary)))
      |> Map.put(:transit_returns, Enum.count(events, &(&1.status == :returned)))
      |> Map.put(:transit_reversals, Enum.count(events, &(&1.status == :reversing)))
      |> Map.put(:transit_forward_ticks, Enum.count(events, &(&1.status == :advancing)))
      |> Map.put(:transit_motor_impulses, length(successful))
      |> Map.put(:transit_minds_committed?, Enum.all?(successful, &match?({:ok, _}, &1.commit)))

    {:reply, enhanced, state}
  end

  @impl true
  def terminate(_reason, state) do
    if is_pid(state.runtime) and Process.alive?(state.runtime) do
      LivingBriarRuntime.stop(state.runtime)
    end

    :ok
  catch
    :exit, _ -> :ok
  end

  defp detach_transit(runtime) do
    inner = :sys.get_state(runtime)

    {transit, regional} =
      Enum.split_with(inner.resident_processes, fn {_id, process} ->
        process.primitive == :cross_region_boundary
      end)

    :sys.replace_state(runtime, fn state ->
      %{state | resident_processes: Map.new(regional)}
    end)

    Map.new(transit)
  end

  defp reattach_transit(runtime, transit) do
    :sys.replace_state(runtime, fn inner ->
      %{inner | resident_processes: Map.merge(inner.resident_processes, transit)}
    end)
  end

  defp advance_transit(runtime, transit, tick) do
    inner = :sys.get_state(runtime)

    {regions, processes, events} =
      transit
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.reduce({inner.regions, %{}, []}, fn {identity_id, process},
                                                 {regions, processes, events} ->
        {regions, updated, status, consequence} =
          advance_one(regions, identity_id, process, inner.lifecycle)

        event = process_event(identity_id, updated, status, tick, consequence)

        processes =
          if status in [:advancing, :reversing, :stationary, :stranded] do
            Map.put(processes, identity_id, updated)
          else
            processes
          end

        {regions, processes, [event | events]}
      end)

    :sys.replace_state(runtime, &%{&1 | regions: regions})
    {processes, Enum.reverse(events)}
  end

  defp advance_one(regions, identity_id, process, lifecycle) do
    source = process.region_id
    destination = process.action.region_id
    extent = Map.get(process, :extent, transit_extent(source, destination))

    {body, regions} =
      case Map.get(process, :body) do
        nil ->
          {resident, source_kernel} =
            CognitiveMaterialKernel.remove_resident(regions[source], identity_id)

          {resident, Map.put(regions, source, source_kernel)}

        resident ->
          {resident, regions}
      end

    velocity = clamp(Map.get(process, :route_velocity, 0.0) * @drag, -1.0, 1.0)
    lateral_velocity = clamp(Map.get(process, :lateral_velocity, 0.0) * @lateral_drag, -1.0, 1.0)

    {velocity, lateral_velocity} =
      if body.energy <= 0.0 do
        {0.0, 0.0}
      else
        {velocity, lateral_velocity}
      end

    distance = abs(velocity) + abs(lateral_velocity) * 0.35
    energy = clamp(body.energy - distance * @energy_per_distance, 0.0, 1.0)
    body = %{body | energy: energy}
    progress = process.accumulated + velocity
    lateral = Map.get(process, :lateral_position, 0.0) + lateral_velocity

    updated =
      process
      |> Map.put(:body, body)
      |> Map.put(:extent, extent)
      |> Map.put(:accumulated, progress)
      |> Map.put(:route_velocity, velocity)
      |> Map.put(:lateral_velocity, lateral_velocity)
      |> Map.put(:lateral_position, lateral)
      |> Map.drop([:heading, :paused?])

    cond do
      progress <= 0.0 and velocity < -@velocity_epsilon ->
        kernel =
          CognitiveMaterialKernel.put_resident(
            regions[source],
            %{body | position: departure_position(process.action.direction)}
          )

        {Map.put(regions, source, kernel), updated, :returned,
         consequence(:returned_to_source_boundary, abs(velocity), 0.12)}

      progress >= extent ->
        case RegionActivationLifecycle.migrate(identity_id, source, destination, [], lifecycle) do
          {:ok, _} ->
            kernel =
              CognitiveMaterialKernel.put_resident(
                regions[destination],
                %{body | position: entry_position(process.action.direction)}
              )

            {Map.put(regions, destination, kernel), updated, :arrived,
             consequence(:crossed_region_boundary, abs(velocity), 0.2)}

          {:error, _} ->
            kernel = CognitiveMaterialKernel.put_resident(regions[source], body)

            {Map.put(regions, source, kernel), updated, :ended,
             consequence(:boundary_crossing_rejected, 0.0, -0.1)}
        end

      body.energy <= 0.0 and abs(velocity) <= @velocity_epsilon ->
        {regions, updated, :stranded, consequence(:transit_stranded, 0.0, -0.2)}

      velocity > @velocity_epsilon ->
        {regions, updated, :advancing,
         consequence(:advanced_in_transit, velocity, motion_coherence(velocity))}

      velocity < -@velocity_epsilon ->
        {regions, updated, :reversing,
         consequence(:reversed_in_transit, abs(velocity), motion_coherence(velocity))}

      true ->
        {regions, updated, :stationary, consequence(:stationary_in_transit, 0.0, 0.0)}
    end
  end

  defp service_transit_cognition(runtime, transit, tick, state) do
    ids =
      transit
      |> Enum.filter(fn {_id, process} -> is_map(Map.get(process, :body)) end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    if rem(tick, state.cadence) == 0 do
      selected = rotate_take(ids, state.cursor, state.budget)
      inner = :sys.get_state(runtime)

      {processes, decisions} =
        Enum.reduce(selected, {transit, []}, fn identity_id, {processes, decisions} ->
          process = Map.fetch!(processes, identity_id)
          context = transit_context(processes, identity_id, process)

          opts = [
            lifecycle_server: inner.lifecycle,
            loop_opts: [
              seed: state.seed + :erlang.phash2({identity_id, :transit}, 10_000),
              output_exploration: 0.82
            ]
          ]

          case InTransitDecision.begin_cycle(process.region_id, identity_id, context, tick, opts) do
            {:ok, token} ->
              {updated, physical} = apply_motor_impulse(process, token.action)

              commit =
                InTransitDecision.commit_cycle(
                  token,
                  physical.features,
                  physical.coherence,
                  opts
                )

              decision = %{
                identity: identity_id,
                from: process.region_id,
                to: process.region_id,
                primitive: token.action.primitive,
                motor_pattern: token.outcome.pattern,
                motor_direction: token.outcome.direction,
                motor_force: token.action.force,
                route_projection: token.action.route_projection,
                lateral_projection: token.action.lateral_projection,
                consequence: physical.kind,
                amount: token.action.route_projection,
                moved?: false,
                process_status: :updated,
                player_observed?: false,
                in_transit?: true,
                commit: commit
              }

              {Map.put(processes, identity_id, updated), [decision | decisions]}

            {:error, reason} ->
              decision = %{
                identity: identity_id,
                from: process.region_id,
                error: reason,
                moved?: false,
                player_observed?: false,
                in_transit?: true
              }

              {processes, [decision | decisions]}
          end
        end)

      {processes, Enum.reverse(decisions), state.cursor + state.budget}
    else
      {transit, [], state.cursor}
    end
  end

  defp transit_context(processes, identity_id, process) do
    %{
      body: process.body,
      progress: process.accumulated,
      extent: Map.get(process, :extent, transit_extent(process.region_id, process.action.region_id)),
      route_velocity: Map.get(process, :route_velocity, 0.0),
      lateral_velocity: Map.get(process, :lateral_velocity, 0.0),
      lateral_position: Map.get(process, :lateral_position, 0.0),
      route_direction: process.action.direction,
      nearby_travelers: nearby_travelers(processes, identity_id, process)
    }
  end

  defp nearby_travelers(processes, identity_id, process) do
    processes
    |> Enum.reject(fn {other_id, _} -> other_id == identity_id end)
    |> Enum.flat_map(fn {other_id, other} ->
      same_route? =
        other.primitive == :cross_region_boundary and
          other.region_id == process.region_id and
          other.action.region_id == process.action.region_id and
          is_map(Map.get(other, :body))

      if same_route? do
        difference = other.accumulated - process.accumulated

        [%{
          identity_id: other_id,
          relative: if(difference >= 0.0, do: :ahead, else: :behind),
          distance: trunc(abs(difference))
        }]
      else
        []
      end
    end)
  end

  defp apply_motor_impulse(process, action) do
    energy = process.body.energy
    coordination = Map.get(action, :coordination, 0.0)
    displaced_factor = if Map.get(action, :displaced?, false), do: 1.0, else: 0.15
    bodily_factor = clamp(energy, 0.0, 1.0)
    gain = displaced_factor * bodily_factor * (0.25 + 0.75 * coordination)

    route_impulse = action.route_projection * gain
    lateral_impulse = action.lateral_projection * gain

    route_velocity =
      clamp(Map.get(process, :route_velocity, 0.0) + route_impulse, -1.0, 1.0)

    lateral_velocity =
      clamp(Map.get(process, :lateral_velocity, 0.0) + lateral_impulse, -1.0, 1.0)

    updated =
      process
      |> Map.put(:route_velocity, route_velocity)
      |> Map.put(:lateral_velocity, lateral_velocity)
      |> Map.put_new(:lateral_position, 0.0)
      |> Map.drop([:heading, :paused?])

    kind =
      cond do
        route_impulse > @velocity_epsilon -> :forward_motor_impulse
        route_impulse < -@velocity_epsilon -> :reverse_motor_impulse
        abs(lateral_impulse) > @velocity_epsilon -> :transverse_motor_impulse
        true -> :weak_motor_impulse
      end

    coherence =
      cond do
        abs(route_impulse) > @velocity_epsilon -> 0.08
        abs(lateral_impulse) > @velocity_epsilon -> 0.02
        true -> -0.01
      end

    {updated, consequence(kind, abs(route_impulse) + abs(lateral_impulse), coherence)}
  end

  defp attach_transit_evidence(runtime, processes, events, decisions) do
    :sys.replace_state(runtime, fn inner ->
      traces =
        case inner.traces do
          [latest | rest] ->
            [%{
               latest
               | decisions: latest.decisions ++ decisions,
                 resident_processes: Map.merge(latest.resident_processes, processes),
                 resident_process_events: latest.resident_process_events ++ events
             }
             | rest]

          [] ->
            []
        end

      %{
        inner
        | resident_processes: Map.merge(inner.resident_processes, processes),
          resident_process_events: Enum.reverse(events) ++ inner.resident_process_events,
          traces: traces,
          failures: inner.failures + Enum.count(decisions, &Map.has_key?(&1, :error))
      }
    end)
  end

  defp observe_decision(%{error: reason} = decision),
    do: %{
      identity: decision.identity,
      region: decision.from,
      result: :failed,
      reason: reason,
      moved?: false,
      in_transit?: true
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
      motor_force: decision.motor_force,
      route_projection: decision.route_projection,
      lateral_projection: decision.lateral_projection,
      moved?: false,
      process_status: decision.process_status,
      in_transit?: true,
      mind_committed?: match?({:ok, _}, decision.commit)
    }

  defp process_event(identity_id, process, status, tick, physical),
    do: %{
      identity: identity_id,
      primitive: :cross_region_boundary,
      region: process.region_id,
      status: status,
      tick: tick,
      amount: physical.amount,
      accumulated: process.accumulated,
      route_velocity: Map.get(process, :route_velocity, 0.0),
      lateral_position: Map.get(process, :lateral_position, 0.0),
      consequence: physical.kind
    }

  defp consequence(kind, amount, coherence),
    do: %{
      kind: kind,
      amount: amount,
      coherence: coherence,
      features: [{:signal, {:physical_consequence, kind}, 1.0}]
    }

  defp motion_coherence(velocity), do: min(0.12, 0.04 + abs(velocity) * 0.08)
  defp transit_extent(:west_fields, :crossroads), do: 3.0
  defp transit_extent(:crossroads, :west_fields), do: 3.0
  defp transit_extent(:crossroads, :east_refuge), do: 4.0
  defp transit_extent(:east_refuge, :crossroads), do: 4.0
  defp transit_extent(_, _), do: 4.0
  defp entry_position(:east), do: {-2, 0}
  defp entry_position(:west), do: {2, 0}
  defp entry_position(_), do: {0, 0}
  defp departure_position(:east), do: {2, 0}
  defp departure_position(:west), do: {-2, 0}
  defp departure_position(_), do: {0, 0}
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
  defp rotate_take(_ids, _cursor, budget) when budget <= 0, do: []
  defp rotate_take([], _cursor, _budget), do: []

  defp rotate_take(ids, cursor, budget) do
    count = length(ids)
    offset = rem(cursor, count)
    rotated = Enum.drop(ids, offset) ++ Enum.take(ids, offset)
    Enum.take(rotated, min(budget, count))
  end
end
