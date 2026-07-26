defmodule Procession.Simulation.RouteEvidence do
  use GenServer

  @moduledoc """
  Owns bounded, expiring evidence about conditions on coarse travel routes.

  Evidence changes low-level physical travel conditions. It does not select narrative
  outcomes or inspect traveler goals. Obstructions must describe a cause and physical
  magnitude; they never set a deterministic blocked journey status.
  """

  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.LiveResolutionManager

  @name __MODULE__
  @default_limit 32

  def start_link(opts \\ []) do
    state = %{
      evidence: %{},
      limit: Keyword.get(opts, :route_evidence_limit, @default_limit),
      resolution_server: Keyword.get(opts, :resolution_server, LiveResolutionManager)
    }

    GenServer.start_link(__MODULE__, state, name: Keyword.get(opts, :name, @name))
  end

  def publish(from, to, evidence_id, effects, tick, ttl \\ 5, server \\ @name)
      when is_integer(tick) and is_integer(ttl) and ttl > 0 do
    GenServer.call(server, {:publish, from, to, evidence_id, effects, tick, ttl})
  end

  def clear(from, to, evidence_id, server \\ @name),
    do: GenServer.call(server, {:clear, from, to, evidence_id})

  def route(from, to, tick, server \\ @name),
    do: GenServer.call(server, {:route, from, to, tick})

  def advance_travel(tick, travel_server \\ CoarseTravel, server \\ @name)
      when is_integer(tick) and tick >= 0 do
    GenServer.call(server, {:advance_travel, tick, travel_server}, :infinity)
  end

  def trace(server \\ @name), do: GenServer.call(server, :trace)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:publish, from, to, evidence_id, effects, tick, ttl}, _from, state) do
    route_key = {from, to}
    record = normalize_record(evidence_id, effects, tick, ttl)

    route_records =
      state.evidence
      |> Map.get(route_key, %{})
      |> Map.put(evidence_id, record)
      |> trim_records(state.limit)

    updated = put_in(state.evidence[route_key], route_records)
    {:reply, {:ok, record}, updated}
  end

  def handle_call({:clear, from, to, evidence_id}, _from, state) do
    route_key = {from, to}

    updated =
      update_in(state.evidence[route_key], fn records ->
        Map.delete(records || %{}, evidence_id)
      end)

    {:reply, :ok, updated}
  end

  def handle_call({:route, from, to, tick}, _from, state) do
    {records, updated} = current_records(state, {from, to}, tick)
    {:reply, aggregate(records, tick), updated}
  end

  def handle_call({:advance_travel, tick, travel_server}, _from, state) do
    {result, updated} = apply_and_advance(tick, travel_server, state)
    {:reply, result, updated}
  end

  def handle_call(:trace, _from, state), do: {:reply, state.evidence, state}

  defp apply_and_advance(tick, travel_server, state) do
    trace = CoarseTravel.trace(travel_server)

    active =
      trace.journeys
      |> Enum.filter(fn {_id, journey} -> journey.status == :in_transit end)

    {evidence_events, state} =
      Enum.reduce(active, {[], state}, fn {identity_id, journey}, {events, acc} ->
        {records, acc} = current_records(acc, {journey.from, journey.to}, tick)
        effects = aggregate(records, tick)

        case apply_effects(identity_id, journey, effects, travel_server, acc.resolution_server) do
          [] -> {events, acc}
          applied -> {events ++ applied, acc}
        end
      end)

    travel = CoarseTravel.advance(1, travel_server)
    {%{tick: tick, evidence_events: evidence_events, travel: travel}, state}
  catch
    :exit, reason -> {%{tick: tick, status: :error, reason: reason}, state}
  end

  defp apply_effects(identity_id, journey, effects, travel_server, resolution_server) do
    if is_nil(effects.divert_to) do
      apply_physical_effects(identity_id, journey, effects, resolution_server)
    else
      duration = max(1, effects.divert_ticks || journey.total_ticks - journey.elapsed_ticks)

      case CoarseTravel.divert(identity_id, effects.divert_to, duration, travel_server) do
        {:ok, _} -> [{:diverted, identity_id, effects.divert_to, duration}]
        {:error, _} -> []
      end
    end
  end

  defp apply_physical_effects(_identity_id, _journey, %{physical?: false}, _server), do: []

  defp apply_physical_effects(identity_id, journey, effects, server) do
    with {:ok, region} <- LiveResolutionManager.fetch(journey.transit_region, server),
         {:ok, commitment} <- fetch_commitment(region, identity_id) do
      base_demand = number(journey.route_profile, :demand)
      extra_demand = max(0.0, effects.demand + base_demand * effects.pressure)
      supplied = max(0.0, effects.supply)
      held = number(commitment, :inventory) + supplied
      consumed = min(held, extra_demand)
      satisfaction = if extra_demand > 0.0, do: consumed / extra_demand, else: 1.0

      energy_delta =
        effects.energy + satisfaction * effects.satisfied_energy -
          (1.0 - satisfaction) * effects.unmet_energy

      updated_commitment =
        commitment
        |> Map.put(:inventory, held - consumed)
        |> Map.update(:consumed, consumed, &(&1 + consumed))
        |> Map.update(
          :energy,
          clamp(energy_delta, 0.0, 1.0),
          &clamp(&1 + energy_delta, 0.0, 1.0)
        )

      commitments =
        region.summary
        |> Map.get(:identity_commitments, %{})
        |> Map.put(identity_id, updated_commitment)

      summary = rebuild_summary(region.summary, commitments, supplied)
      updated_region = %{region | summary: summary}

      case LiveResolutionManager.put(updated_region, server) do
        {:ok, _} ->
          [
            {:route_effects, identity_id,
             %{
               sources: effects.sources,
               obstructions: effects.obstructions,
               supplied: supplied,
               consumed: consumed,
               energy_delta: energy_delta
             }}
          ]

        {:error, _} ->
          []
      end
    else
      _ -> []
    end
  end

  defp current_records(state, route_key, tick) do
    records =
      state.evidence
      |> Map.get(route_key, %{})
      |> Enum.reject(fn {_id, record} -> record.expires_at < tick end)
      |> Map.new()

    updated =
      if map_size(records) == 0,
        do: update_in(state.evidence, &Map.delete(&1, route_key)),
        else: put_in(state.evidence[route_key], records)

    ordered =
      records
      |> Map.values()
      |> Enum.sort_by(fn record -> {record.observed_at, inspect(record.id)} end)

    {ordered, updated}
  end

  defp aggregate(records, tick) do
    records
    |> Enum.reduce(empty_effects(), fn record, acc ->
      effects = record.effects
      obstruction = obstruction_effects(Map.get(effects, :obstruction))
      one_shot_supply = if record.observed_at == tick, do: number(effects, :supply), else: 0.0

      %{
        acc
        | pressure:
            clamp(
              acc.pressure + number(effects, :pressure) + obstruction.pressure,
              0.0,
              4.0
            ),
          demand: max(0.0, acc.demand + number(effects, :demand) + obstruction.demand),
          energy:
            clamp(acc.energy + number(effects, :energy) + obstruction.energy, -1.0, 1.0),
          satisfied_energy:
            max(0.0, acc.satisfied_energy + number(effects, :satisfied_energy)),
          unmet_energy:
            max(
              0.0,
              acc.unmet_energy + number(effects, :unmet_energy) + obstruction.unmet_energy
            ),
          supply: max(0.0, acc.supply + one_shot_supply),
          divert_to: Map.get(effects, :divert_to, acc.divert_to),
          divert_ticks: Map.get(effects, :divert_ticks, acc.divert_ticks),
          sources: [record.id | acc.sources],
          obstructions: obstruction_list(acc.obstructions, obstruction),
          physical?: acc.physical? or physical_effect?(effects, one_shot_supply, obstruction)
      }
    end)
    |> Map.update!(:sources, &Enum.reverse/1)
    |> Map.update!(:obstructions, &Enum.reverse/1)
  end

  defp obstruction_effects(nil), do: empty_obstruction()

  defp obstruction_effects(obstruction) when is_map(obstruction) do
    cause = Map.fetch!(obstruction, :cause)
    severity = clamp(number(obstruction, :severity), 0.0, 1.0)
    extent = clamp(number(obstruction, :extent), 0.0, 1.0)
    clearance = clamp(number(obstruction, :clearance), 0.0, 1.0)
    net = severity * extent * (1.0 - clearance)

    %{
      cause: cause,
      net: net,
      pressure: net * 2.0,
      demand: net * 0.02,
      energy: -net * 0.01,
      unmet_energy: net * 0.04
    }
  end

  defp obstruction_effects(_),
    do: raise(ArgumentError, "route obstruction must be a map with a cause")

  defp empty_obstruction do
    %{cause: nil, net: 0.0, pressure: 0.0, demand: 0.0, energy: 0.0, unmet_energy: 0.0}
  end

  defp obstruction_list(list, %{cause: nil}), do: list
  defp obstruction_list(list, obstruction), do: [Map.take(obstruction, [:cause, :net]) | list]

  defp empty_effects do
    %{
      pressure: 0.0,
      demand: 0.0,
      energy: 0.0,
      satisfied_energy: 0.0,
      unmet_energy: 0.0,
      supply: 0.0,
      divert_to: nil,
      divert_ticks: nil,
      sources: [],
      obstructions: [],
      physical?: false
    }
  end

  defp normalize_record(id, effects, tick, ttl) when is_map(effects) do
    validate_effects!(effects)
    %{id: id, effects: effects, observed_at: tick, expires_at: tick + ttl - 1}
  end

  defp normalize_record(_id, _effects, _tick, _ttl),
    do: raise(ArgumentError, "route effects must be a map")

  defp validate_effects!(%{blocked: _}),
    do: raise(ArgumentError, "blocked is a conclusion; publish a causal obstruction instead")

  defp validate_effects!(%{obstruction: obstruction}) when is_map(obstruction) do
    if Map.has_key?(obstruction, :cause),
      do: :ok,
      else: raise(ArgumentError, "route obstruction requires a cause")
  end

  defp validate_effects!(_effects), do: :ok

  defp trim_records(records, limit) do
    records
    |> Enum.sort_by(fn {_id, record} -> {-record.observed_at, inspect(record.id)} end)
    |> Enum.take(max(limit, 1))
    |> Map.new()
  end

  defp fetch_commitment(region, identity_id) do
    case get_in(region.summary, [:identity_commitments, identity_id]) do
      nil -> {:error, :identity_commitment_missing}
      commitment -> {:ok, commitment}
    end
  end

  defp rebuild_summary(summary, commitments, supplied) do
    values = Map.values(commitments)
    held = Enum.sum(Enum.map(values, &number(&1, :inventory)))
    consumed = Enum.sum(Enum.map(values, &number(&1, :consumed)))
    available = number(summary, :available_stock)

    summary
    |> Map.put(:identity_commitments, commitments)
    |> Map.put(:held_stock, held)
    |> Map.put(:consumed_stock, consumed)
    |> Map.put(:available_stock, available)
    |> Map.put(:total_stock, held + consumed + available)
    |> Map.put(:mean_energy, mean(values, :energy))
    |> Map.update(:external_inflow, supplied, &(&1 + supplied))
  end

  defp physical_effect?(effects, one_shot_supply, obstruction) do
    one_shot_supply != 0.0 or obstruction.net != 0.0 or
      Enum.any?(
        [:pressure, :demand, :energy, :satisfied_energy, :unmet_energy],
        fn key -> number(effects, key) != 0.0 end
      )
  end

  defp mean([], _key), do: 0.0
  defp mean(values, key), do: Enum.sum(Enum.map(values, &number(&1, key))) / length(values)

  defp number(map, key),
    do: if(is_number(Map.get(map, key)), do: Map.get(map, key) * 1.0, else: 0.0)

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end
