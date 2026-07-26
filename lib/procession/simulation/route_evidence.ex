defmodule Procession.Simulation.RouteEvidence do
  use GenServer

  @moduledoc """
  Owns bounded, expiring evidence about physical conditions on coarse travel routes.

  Stored conditions describe observer-independent causes and physical dimensions. Whether a
  traveler experiences those conditions as difficult, obstructive, dangerous, or irrelevant is
  derived from the traveler's current bodily commitment; those interpretations are never stored.
  """

  alias Procession.Simulation.CoarseTravel
  alias Procession.Simulation.LiveResolutionManager

  @name __MODULE__
  @default_limit 32
  @condition_fields [
    :affected_extent,
    :material_resistance,
    :surface_instability,
    :displacement,
    :visibility_loss,
    :environmental_intensity
  ]

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
    with :ok <- validate_effects(effects) do
      GenServer.call(server, {:publish, from, to, evidence_id, normalize_effects(effects), tick, ttl})
    end
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
    record = %{id: evidence_id, effects: effects, observed_at: tick, expires_at: tick + ttl - 1}

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
    active =
      travel_server
      |> CoarseTravel.trace()
      |> Map.fetch!(:journeys)
      |> Enum.filter(fn {_id, journey} -> journey.status == :in_transit end)

    {evidence_events, state} =
      Enum.reduce(active, {[], state}, fn {identity_id, journey}, {events, acc} ->
        {records, acc} = current_records(acc, {journey.from, journey.to}, tick)
        effects = aggregate(records, tick)

        applied =
          apply_effects(identity_id, journey, effects, travel_server, acc.resolution_server)

        {events ++ applied, acc}
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
      experienced = experience_conditions(effects.conditions, commitment)
      base_demand = number(journey.route_profile, :demand)

      extra_demand =
        max(0.0, effects.demand + base_demand * effects.pressure + experienced.demand)

      supplied = max(0.0, effects.supply)
      held = number(commitment, :inventory) + supplied
      consumed = min(held, extra_demand)
      satisfaction = if extra_demand > 0.0, do: consumed / extra_demand, else: 1.0

      energy_delta =
        effects.energy + experienced.energy + satisfaction * effects.satisfied_energy -
          (1.0 - satisfaction) * (effects.unmet_energy + experienced.unmet_energy)

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

      updated_region = %{region | summary: rebuild_summary(region.summary, commitments, supplied)}

      case LiveResolutionManager.put(updated_region, server) do
        {:ok, _} ->
          [
            {:route_effects, identity_id,
             %{
               sources: effects.sources,
               experienced_conditions: experienced.details,
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
      one_shot_supply = if record.observed_at == tick, do: number(effects, :supply), else: 0.0

      %{
        acc
        | pressure: clamp(acc.pressure + number(effects, :pressure), 0.0, 4.0),
          demand: max(0.0, acc.demand + number(effects, :demand)),
          energy: clamp(acc.energy + number(effects, :energy), -1.0, 1.0),
          satisfied_energy:
            max(0.0, acc.satisfied_energy + number(effects, :satisfied_energy)),
          unmet_energy: max(0.0, acc.unmet_energy + number(effects, :unmet_energy)),
          supply: max(0.0, acc.supply + one_shot_supply),
          divert_to: Map.get(effects, :divert_to, acc.divert_to),
          divert_ticks: Map.get(effects, :divert_ticks, acc.divert_ticks),
          sources: [record.id | acc.sources],
          conditions: acc.conditions ++ Map.get(effects, :conditions, []),
          physical?:
            acc.physical? or physical_effect?(effects, one_shot_supply)
      }
    end)
    |> Map.update!(:sources, &Enum.reverse/1)
  end

  defp experience_conditions(conditions, commitment) do
    mobility = clamp(number(commitment, :mobility), 0.0, 1.0)
    energy = clamp(number(commitment, :energy), 0.0, 1.0)
    capability = clamp(mobility * 0.7 + energy * 0.3, 0.0, 1.0)

    Enum.reduce(conditions, %{demand: 0.0, energy: 0.0, unmet_energy: 0.0, details: []}, fn condition,
                                                                                              acc ->
      physical_load =
        condition
        |> condition_load()
        |> Kernel.*(0.35 + 0.65 * (1.0 - capability))

      %{
        demand: acc.demand + physical_load * 0.02,
        energy: acc.energy - physical_load * 0.01,
        unmet_energy: acc.unmet_energy + physical_load * 0.04,
        details: [
          %{cause: condition.cause, experienced_resistance: physical_load} | acc.details
        ]
      }
    end)
    |> Map.update!(:details, &Enum.reverse/1)
  end

  defp condition_load(condition) do
    affected_extent = number(condition, :affected_extent)

    dimensions =
      @condition_fields
      |> List.delete(:affected_extent)
      |> Enum.map(&number(condition, &1))

    mean_dimension = Enum.sum(dimensions) / length(dimensions)
    clamp(affected_extent * mean_dimension, 0.0, 1.0)
  end

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
      conditions: [],
      physical?: false
    }
  end

  defp validate_effects(effects) when not is_map(effects),
    do: {:error, "route effects must be a map"}

  defp validate_effects(effects) do
    cond do
      Map.has_key?(effects, :blocked) ->
        {:error, "blocked is an observed outcome, not stored route evidence"}

      Map.has_key?(effects, :obstruction) ->
        {:error, "obstruction is an observer interpretation; publish physical conditions"}

      true ->
        validate_conditions(Map.get(effects, :conditions, []))
    end
  end

  defp validate_conditions(conditions) when not is_list(conditions),
    do: {:error, "route conditions must be a list"}

  defp validate_conditions(conditions) do
    Enum.reduce_while(conditions, :ok, fn condition, :ok ->
      case validate_condition(condition) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_condition(condition) when not is_map(condition),
    do: {:error, "each route condition must be a map"}

  defp validate_condition(condition) do
    cond do
      not Map.has_key?(condition, :cause) or is_nil(condition.cause) ->
        {:error, "each route condition requires a physical cause"}

      Enum.any?([:severity, :extent, :clearance, :obstruction], &Map.has_key?(condition, &1)) ->
        {:error, "route conditions must contain physical dimensions, not interpreted difficulty"}

      true ->
        :ok
    end
  end

  defp normalize_effects(effects) do
    Map.update(effects, :conditions, [], fn conditions ->
      Enum.map(conditions, fn condition ->
        Enum.reduce(@condition_fields, condition, fn field, acc ->
          Map.put(acc, field, clamp(number(condition, field), 0.0, 1.0))
        end)
      end)
    end)
  end

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

  defp physical_effect?(effects, one_shot_supply) do
    one_shot_supply != 0.0 or Map.get(effects, :conditions, []) != [] or
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
