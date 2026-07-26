defmodule Procession.Simulation.CoarseTravel do
  use GenServer

  @moduledoc """
  Advances dormant anchored identities through bounded in-transit regions.

  Travel reuses the guarded region lifecycle. Departure migrates an anchored identity into
  a reusable compressed route region, each travel tick updates that identity's coarse
  physical commitment, and arrival migrates it into the compressed destination. Elapsed
  time and achieved progress are tracked separately so resistance can slow movement without
  stopping time or creating a categorical blocked state.
  """

  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle

  @name __MODULE__

  def start_link(opts \\ []) do
    state = %{
      journeys: %{},
      routes: %{},
      history: [],
      resolution_server: Keyword.get(opts, :resolution_server, LiveResolutionManager),
      lifecycle_server: Keyword.get(opts, :lifecycle_server, RegionActivationLifecycle)
    }

    GenServer.start_link(__MODULE__, state, name: Keyword.get(opts, :name, @name))
  end

  def depart(identity_id, from_region, to_region, duration_ticks, opts \\ [], server \\ @name),
    do:
      GenServer.call(
        server,
        {:depart, identity_id, from_region, to_region, duration_ticks, opts},
        :infinity
      )

  def advance(ticks \\ 1, server \\ @name) when is_integer(ticks) and ticks >= 0,
    do: GenServer.call(server, {:advance, ticks}, :infinity)

  def set_progress_factor(identity_id, factor, server \\ @name) when is_number(factor),
    do: GenServer.call(server, {:set_progress_factor, identity_id, factor * 1.0})

  def divert(identity_id, to_region, remaining_ticks, server \\ @name)
      when is_integer(remaining_ticks) and remaining_ticks > 0,
      do: GenServer.call(server, {:divert, identity_id, to_region, remaining_ticks})

  def stop(identity_id, reason \\ :stopped, server \\ @name),
    do: GenServer.call(server, {:stop, identity_id, reason})

  def journey(identity_id, server \\ @name), do: GenServer.call(server, {:journey, identity_id})
  def trace(server \\ @name), do: GenServer.call(server, :trace)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:depart, identity_id, from, to, duration, opts}, _from, state) do
    with :ok <- validate_departure(identity_id, from, to, duration, state),
         {:ok, transit_id, state} <- ensure_route(from, to, opts, state),
         {:ok, _reply} <-
           RegionActivationLifecycle.migrate(
             identity_id,
             from,
             transit_id,
             opts,
             state.lifecycle_server
           ) do
      journey = %{
        identity_id: identity_id,
        from: from,
        to: to,
        transit_region: transit_id,
        elapsed_ticks: 0,
        total_ticks: duration,
        progress: 0.0,
        required_progress: duration * 1.0,
        next_progress_factor: 1.0,
        status: :in_transit,
        route_profile: route_profile(opts),
        last_outcome: :departed
      }

      updated = put_in(state.journeys[identity_id], journey)
      {:reply, {:ok, journey_trace(journey)}, updated}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:advance, 0}, _from, state) do
    {:reply, %{ticks: 0, events: [], journeys: trace_journeys(state.journeys)}, state}
  end

  def handle_call({:advance, ticks}, _from, state) do
    {events, updated} =
      Enum.reduce(1..ticks, {[], state}, fn _, {events, acc} ->
        {step_events, next} = advance_once(acc)
        {events ++ step_events, next}
      end)

    {:reply, %{ticks: ticks, events: events, journeys: trace_journeys(updated.journeys)}, updated}
  end

  def handle_call({:set_progress_factor, identity_id, factor}, _from, state) do
    case Map.fetch(state.journeys, identity_id) do
      {:ok, %{status: :in_transit} = journey} ->
        bounded = clamp(factor, 0.0, 1.0)
        current = Map.get(journey, :next_progress_factor, 1.0)
        updated_journey = Map.put(journey, :next_progress_factor, min(current, bounded))
        {:reply, {:ok, journey_trace(updated_journey)}, put_in(state.journeys[identity_id], updated_journey)}

      {:ok, _journey} ->
        {:reply, {:error, :journey_not_active}, state}

      :error ->
        {:reply, {:error, :journey_not_found}, state}
    end
  end

  def handle_call({:divert, identity_id, destination, remaining_ticks}, _from, state) do
    case Map.fetch(state.journeys, identity_id) do
      {:ok, %{status: status} = journey} when status in [:in_transit, :stranded] ->
        updated_journey = %{
          journey
          | to: destination,
            elapsed_ticks: 0,
            total_ticks: remaining_ticks,
            progress: 0.0,
            required_progress: remaining_ticks * 1.0,
            next_progress_factor: 1.0,
            status: :in_transit,
            last_outcome: :diverted
        }

        {:reply, {:ok, journey_trace(updated_journey)}, put_in(state.journeys[identity_id], updated_journey)}

      {:ok, _journey} ->
        {:reply, {:error, :journey_not_active}, state}

      :error ->
        {:reply, {:error, :journey_not_found}, state}
    end
  end

  def handle_call({:stop, identity_id, reason}, _from, state) do
    case Map.fetch(state.journeys, identity_id) do
      {:ok, %{status: :in_transit} = journey} ->
        stopped = %{journey | status: :stranded, last_outcome: reason}
        {:reply, {:ok, journey_trace(stopped)}, put_in(state.journeys[identity_id], stopped)}

      {:ok, _journey} ->
        {:reply, {:error, :journey_not_active}, state}

      :error ->
        {:reply, {:error, :journey_not_found}, state}
    end
  end

  def handle_call({:journey, identity_id}, _from, state) do
    reply =
      case Map.fetch(state.journeys, identity_id) do
        {:ok, journey} -> {:ok, journey_trace(journey)}
        :error -> {:error, :journey_not_found}
      end

    {:reply, reply, state}
  end

  def handle_call(:trace, _from, state) do
    {:reply,
     %{
       journeys: trace_journeys(state.journeys),
       routes: state.routes,
       history: Enum.reverse(state.history)
     }, state}
  end

  defp advance_once(state) do
    active =
      state.journeys
      |> Enum.filter(fn {_id, journey} -> journey.status == :in_transit end)

    {route_events, state} =
      active
      |> Enum.group_by(fn {_id, journey} -> journey.transit_region end)
      |> Enum.reduce({[], state}, fn {transit_id, entries}, {events, acc} ->
        ids = Enum.map(entries, &elem(&1, 0))

        case advance_route(transit_id, ids, acc) do
          {:ok, route_event} ->
            {[route_event | events], acc}

          {:error, reason} ->
            failed = Enum.reduce(ids, acc, &fail_journey(&2, &1, {:route_advance_failed, reason}))
            {[{:route_failed, transit_id, reason} | events], failed}
        end
      end)

    Enum.reduce(active, {Enum.reverse(route_events), state}, fn {identity_id, _old}, {events, acc} ->
      case Map.fetch(acc.journeys, identity_id) do
        {:ok, %{status: :in_transit} = journey} ->
          progress_factor = clamp(Map.get(journey, :next_progress_factor, 1.0), 0.0, 1.0)
          progress = Map.get(journey, :progress, journey.elapsed_ticks * 1.0) + progress_factor
          required_progress = Map.get(journey, :required_progress, journey.total_ticks * 1.0)

          progressed = %{
            journey
            | elapsed_ticks: journey.elapsed_ticks + 1,
              progress: progress,
              required_progress: required_progress,
              next_progress_factor: 1.0,
              last_outcome: :progressed
          }

          acc = put_in(acc.journeys[identity_id], progressed)

          cond do
            exhausted?(progressed, acc) ->
              failed = fail_journey(acc, identity_id, :exhausted)
              {[{:stranded, identity_id, :exhausted} | events], failed}

            progressed.progress >= progressed.required_progress ->
              arrive(identity_id, progressed, events, acc)

            true ->
              {[{:progressed, identity_id, progressed.elapsed_ticks} | events], acc}
          end

        _ ->
          {events, acc}
      end
    end)
  end

  defp arrive(identity_id, journey, events, state) do
    case RegionActivationLifecycle.migrate(
           identity_id,
           journey.transit_region,
           journey.to,
           [],
           state.lifecycle_server
         ) do
      {:ok, _reply} ->
        arrived = %{journey | status: :arrived, last_outcome: :arrived}

        state =
          state
          |> put_in([:journeys, identity_id], arrived)
          |> update_in([:history], &[journey_trace(arrived) | &1])

        {[{:arrived, identity_id, journey.to} | events], state}

      {:error, reason} ->
        failed = fail_journey(state, identity_id, {:arrival_failed, reason})
        {[{:stranded, identity_id, {:arrival_failed, reason}} | events], failed}
    end
  end

  defp advance_route(transit_id, identity_ids, state) do
    with {:ok, region} <- LiveResolutionManager.fetch(transit_id, state.resolution_server),
         true <- region.resolution in [:coarse, :inert] || {:error, :transit_region_not_compressed} do
      profile = Map.fetch!(state.routes, transit_id).profile
      demand = profile.demand * (1.0 + profile.pressure)
      satisfied_gain = profile.satisfied_energy_gain
      unmet_penalty = profile.unmet_energy_penalty * (1.0 + profile.pressure)
      baseline_decay = profile.energy_decay
      commitments = Map.get(region.summary, :identity_commitments, %{})

      updated_commitments =
        Enum.reduce(identity_ids, commitments, fn identity_id, acc ->
          Map.update!(acc, identity_id, fn commitment ->
            held = number(commitment, :inventory)
            consumed = min(held, demand)
            satisfaction = if demand > 0.0, do: consumed / demand, else: 1.0

            energy_delta =
              satisfaction * satisfied_gain -
                (1.0 - satisfaction) * unmet_penalty - baseline_decay

            commitment
            |> Map.put(:inventory, held - consumed)
            |> Map.update(:consumed, consumed, &(&1 + consumed))
            |> Map.update(
              :energy,
              clamp(energy_delta, 0.0, 1.0),
              &clamp(&1 + energy_delta, 0.0, 1.0)
            )
          end)
        end)

      summary = rebuild_transit_summary(region.summary, updated_commitments)
      updated_region = %{
        region
        | tick: region.tick + 1,
          summary: Map.put(summary, :tick, region.tick + 1)
      }

      case LiveResolutionManager.put(updated_region, state.resolution_server) do
        {:ok, _trace} -> {:ok, {:route_advanced, transit_id, identity_ids}}
        {:error, reason} -> {:error, reason}
      end
    else
      false -> {:error, :transit_region_not_compressed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp rebuild_transit_summary(summary, commitments) do
    values = Map.values(commitments)
    held = Enum.sum(Enum.map(values, &number(&1, :inventory)))
    consumed = Enum.sum(Enum.map(values, &number(&1, :consumed)))

    summary
    |> Map.put(:identity_commitments, commitments)
    |> Map.put(:population, length(values))
    |> Map.put(:held_stock, held)
    |> Map.put(:consumed_stock, consumed)
    |> Map.put(:total_stock, held + consumed + Map.get(summary, :available_stock, 0.0))
    |> Map.put(:mean_energy, mean(values, :energy))
    |> Map.put(:mean_mobility, mean(values, :mobility))
  end

  defp exhausted?(journey, state) do
    case LiveResolutionManager.fetch(journey.transit_region, state.resolution_server) do
      {:ok, region} ->
        energy =
          get_in(region.summary, [:identity_commitments, journey.identity_id, :energy]) || 0.0

        energy <= journey.route_profile.failure_energy

      _ ->
        true
    end
  end

  defp ensure_route(from, to, opts, state) do
    profile = route_profile(opts)
    transit_id = transit_region_id(from, to, profile)

    if Map.has_key?(state.routes, transit_id) do
      {:ok, transit_id, state}
    else
      region = MultiResolutionRegion.new(id: transit_id, entities: [], resources: [])

      with {:ok, _trace} <- LiveResolutionManager.put(region, state.resolution_server),
           {:ok, _trace} <-
             RegionActivationLifecycle.deactivate(
               transit_id,
               [inert: true],
               state.lifecycle_server
             ) do
        route = %{from: from, to: to, profile: profile}
        {:ok, transit_id, put_in(state.routes[transit_id], route)}
      end
    end
  end

  defp validate_departure(identity_id, from, to, duration, state) do
    cond do
      Map.has_key?(state.journeys, identity_id) and
          state.journeys[identity_id].status in [:in_transit, :stranded] ->
        {:error, :identity_already_in_transit}

      from == to ->
        {:error, :same_region_travel}

      not is_integer(duration) or duration <= 0 ->
        {:error, :invalid_travel_duration}

      true ->
        :ok
    end
  end

  defp route_profile(opts) do
    %{
      demand: max(0.0, Keyword.get(opts, :travel_demand, 0.01) * 1.0),
      pressure: clamp(Keyword.get(opts, :route_pressure, 0.0) * 1.0, 0.0, 4.0),
      satisfied_energy_gain:
        max(0.0, Keyword.get(opts, :satisfied_energy_gain, 0.001) * 1.0),
      unmet_energy_penalty:
        max(0.0, Keyword.get(opts, :unmet_energy_penalty, 0.02) * 1.0),
      energy_decay: max(0.0, Keyword.get(opts, :travel_energy_decay, 0.002) * 1.0),
      failure_energy:
        clamp(Keyword.get(opts, :failure_energy, 0.01) * 1.0, 0.0, 1.0)
    }
  end

  defp transit_region_id(from, to, profile) do
    digest = :erlang.phash2({from, to, profile}, 1_000_000_000)
    "__transit__:#{digest}"
  end

  defp fail_journey(state, identity_id, reason) do
    update_in(state.journeys[identity_id], fn journey ->
      %{journey | status: :stranded, last_outcome: reason}
    end)
  end

  defp journey_trace(journey),
    do: Map.drop(journey, [:route_profile]) |> Map.put(:route_profile, journey.route_profile)

  defp trace_journeys(journeys),
    do: Map.new(journeys, fn {id, journey} -> {id, journey_trace(journey)} end)

  defp mean([], _key), do: 0.0
  defp mean(values, key), do: Enum.sum(Enum.map(values, &number(&1, key))) / length(values)

  defp number(map, key),
    do: if(is_number(Map.get(map, key)), do: Map.get(map, key) * 1.0, else: 0.0)

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end
