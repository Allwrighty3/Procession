defmodule Procession.Simulation.RouteEvidence do
  use GenServer

  @moduledoc """
  Bounded, expiring physical evidence for directed coarse-travel routes.

  Evidence is expressed as low-level effects rather than named narrative outcomes. The owner
  does not decide whether a traveler arrives, diverts, or becomes stranded.
  """

  @name __MODULE__
  @neutral %{
    demand_pressure: 0.0,
    energy_pressure: 0.0,
    movement_resistance: 0.0,
    support: 0.0,
    route_stock: 0.0,
    evidence_count: 0
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{evidence: %{}}, name: Keyword.get(opts, :name, @name))
  end

  def publish(from, to, effects, tick, opts \\ [], server \\ @name)
      when is_integer(tick) and tick >= 0 do
    GenServer.call(server, {:publish, from, to, effects, tick, opts})
  end

  def effective(from, to, tick, server \\ @name) when is_integer(tick) and tick >= 0,
    do: GenServer.call(server, {:effective, from, to, tick})

  def trace(server \\ @name), do: GenServer.call(server, :trace)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:publish, from, to, effects, tick, opts}, _from, state) do
    ttl = max(1, Keyword.get(opts, :ttl_ticks, 5))
    source = Keyword.get(opts, :source, :anonymous)
    normalized = normalize(effects)

    entry = %{
      effects: normalized,
      observed_at: tick,
      expires_at: tick + ttl,
      source: source
    }

    key = {from, to}
    updated = update_in(state.evidence[key], fn entries -> [entry | (entries || [])] end)
    {:reply, {:ok, entry}, updated}
  end

  def handle_call({:effective, from, to, tick}, _from, state) do
    key = {from, to}
    active = state.evidence |> Map.get(key, []) |> Enum.filter(&(&1.expires_at >= tick))
    updated = put_in(state.evidence[key], active)
    {:reply, aggregate(active), updated}
  end

  def handle_call(:trace, _from, state) do
    trace =
      Map.new(state.evidence, fn {route, entries} ->
        {route,
         Enum.map(entries, fn entry ->
           %{source: entry.source, observed_at: entry.observed_at, expires_at: entry.expires_at, effects: entry.effects}
         end)}
      end)

    {:reply, trace, state}
  end

  defp aggregate([]), do: @neutral

  defp aggregate(entries) do
    Enum.reduce(entries, @neutral, fn entry, acc ->
      effects = entry.effects

      %{
        demand_pressure: clamp(acc.demand_pressure + effects.demand_pressure, 0.0, 4.0),
        energy_pressure: clamp(acc.energy_pressure + effects.energy_pressure, 0.0, 4.0),
        movement_resistance:
          clamp(max(acc.movement_resistance, effects.movement_resistance), 0.0, 1.0),
        support: clamp(acc.support + effects.support, 0.0, 1.0),
        route_stock: max(0.0, acc.route_stock + effects.route_stock),
        evidence_count: acc.evidence_count + 1
      }
    end)
  end

  defp normalize(effects) when is_map(effects) do
    %{
      demand_pressure: bounded(effects, :demand_pressure, 0.0, 4.0),
      energy_pressure: bounded(effects, :energy_pressure, 0.0, 4.0),
      movement_resistance: bounded(effects, :movement_resistance, 0.0, 1.0),
      support: bounded(effects, :support, 0.0, 1.0),
      route_stock: max(0.0, number(effects, :route_stock))
    }
  end

  defp normalize(_effects), do: normalize(%{})

  defp bounded(map, key, minimum, maximum),
    do: map |> number(key) |> clamp(minimum, maximum)

  defp number(map, key) do
    value = Map.get(map, key, 0.0)
    if is_number(value), do: value * 1.0, else: 0.0
  end

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end
