defmodule Procession.Simulation.AutomaticResolutionPolicy do
  use GenServer

  @moduledoc """
  Chooses region resolution from observable causal relevance.

  The policy does not inspect entity goals, preferred actions, or hidden narrative
  importance. Callers provide grounded observations such as player presence,
  physical distance, unresolved cross-region dependencies, recent event intensity,
  and observer-derived salience. Hysteresis and minimum residence times prevent
  resolution thrashing.
  """

  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.RegionActivationLifecycle

  @name __MODULE__

  def start_link(opts \\ []) do
    state = %{
      observations: %{},
      transitions: %{},
      resolution_server: Keyword.get(opts, :resolution_server, LiveResolutionManager),
      lifecycle_server: Keyword.get(opts, :lifecycle_server, RegionActivationLifecycle),
      config: Keyword.get(opts, :config, [])
    }

    GenServer.start_link(__MODULE__, state, name: Keyword.get(opts, :name, @name))
  end

  def observe(region_id, observation, server \\ @name) when is_map(observation),
    do: GenServer.call(server, {:observe, region_id, observation})

  def forget(region_id, server \\ @name), do: GenServer.call(server, {:forget, region_id})

  def reconcile(tick, opts \\ [], server \\ @name) when is_integer(tick),
    do: GenServer.call(server, {:reconcile, tick, opts}, :infinity)

  def trace(server \\ @name), do: GenServer.call(server, :trace)

  @doc "Pure relevance score used by the live coordinator and tests."
  def relevance(observation, tick, opts \\ []) when is_map(observation) and is_integer(tick) do
    distance = max(number(observation, :distance, Keyword.get(opts, :default_distance, 1.0e6)), 0.0)
    distance_scale = max(Keyword.get(opts, :distance_scale, 8.0), 0.001)
    proximity = :math.exp(-distance / distance_scale)
    dependency = clamp(number(observation, :unresolved_dependencies, 0.0), 0.0, 1.0)
    salience = clamp(number(observation, :salience, 0.0), 0.0, 1.0)
    event = clamp(number(observation, :event_intensity, 0.0), 0.0, 1.0)
    observed_tick = Map.get(observation, :last_observed_tick, tick)
    age = max(tick - observed_tick, 0)
    recency_half_life = max(Keyword.get(opts, :recency_half_life, 40.0), 0.001)
    recency = :math.pow(0.5, age / recency_half_life)

    base =
      proximity * Keyword.get(opts, :proximity_weight, 0.40) +
        dependency * Keyword.get(opts, :dependency_weight, 0.25) +
        salience * Keyword.get(opts, :salience_weight, 0.20) +
        event * recency * Keyword.get(opts, :event_weight, 0.15)

    cond do
      active_player_presence?(observation, tick, opts) -> 2.0
      truthy?(observation, :pinned) -> 1.5
      true -> clamp(base, 0.0, 1.0)
    end
  end

  @doc "Returns :live or :compressed without mutating processes."
  def desired_resolution(current, observation, tick, last_transition_tick, opts \\ []) do
    score = relevance(observation, tick, opts)
    activate_at = Keyword.get(opts, :activate_at, 0.55)
    deactivate_below = Keyword.get(opts, :deactivate_below, 0.25)
    minimum_live_ticks = Keyword.get(opts, :minimum_live_ticks, 20)
    minimum_dormant_ticks = Keyword.get(opts, :minimum_dormant_ticks, 10)
    residence = max(tick - last_transition_tick, 0)

    cond do
      active_player_presence?(observation, tick, opts) or truthy?(observation, :pinned) -> :live
      current == :live and residence < minimum_live_ticks -> :live
      current in [:coarse, :inert] and residence < minimum_dormant_ticks -> :compressed
      current == :live and score < deactivate_below -> :compressed
      current in [:coarse, :inert] and score >= activate_at -> :live
      current == :live -> :live
      true -> :compressed
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:observe, region_id, observation}, _from, state) do
    previous = Map.get(state.observations, region_id, %{})
    updated = Map.merge(previous, observation)
    {:reply, :ok, put_in(state.observations[region_id], updated)}
  end

  def handle_call({:forget, region_id}, _from, state) do
    updated = %{state | observations: Map.delete(state.observations, region_id)}
    {:reply, :ok, updated}
  end

  def handle_call({:reconcile, tick, opts}, _from, state) do
    effective = Keyword.merge(state.config, opts)
    regions = LiveResolutionManager.trace(state.resolution_server)
    ranked = rank_regions(regions, state.observations, tick, effective)
    live_budget = max(Keyword.get(effective, :max_live_regions, 12), 0)
    selected_live = select_live(ranked, live_budget, tick, effective)

    {results, updated} =
      Enum.map_reduce(ranked, state, fn entry, acc ->
        reconcile_region(entry, selected_live, tick, effective, acc)
      end)

    {:reply, results, updated}
  end

  def handle_call(:trace, _from, state) do
    {:reply, %{observations: state.observations, transitions: state.transitions}, state}
  end

  defp rank_regions(regions, observations, tick, opts) do
    regions
    |> Enum.map(fn {id, trace} ->
      observation = Map.get(observations, id, %{})
      %{id: id, current: trace.resolution, observation: observation, score: relevance(observation, tick, opts)}
    end)
    |> Enum.sort_by(fn entry -> {-entry.score, entry.id} end)
  end

  defp select_live(ranked, budget, tick, opts) do
    forced =
      ranked
      |> Enum.filter(fn entry ->
        active_player_presence?(entry.observation, tick, opts) or truthy?(entry.observation, :pinned)
      end)
      |> Enum.map(& &1.id)

    ordinary =
      ranked
      |> Enum.reject(&(&1.id in forced))
      |> Enum.take(max(budget - length(forced), 0))
      |> Enum.map(& &1.id)

    MapSet.new(forced ++ ordinary)
  end

  defp reconcile_region(entry, selected_live, tick, opts, state) do
    last_transition = Map.get(state.transitions, entry.id, 0)

    desired =
      desired_resolution(entry.current, entry.observation, tick, last_transition, opts)

    desired = if desired == :live and not MapSet.member?(selected_live, entry.id), do: :compressed, else: desired

    case {entry.current, desired} do
      {:live, :compressed} ->
        case RegionActivationLifecycle.deactivate(entry.id, opts, state.lifecycle_server) do
          {:ok, trace} ->
            result = %{region_id: entry.id, action: :deactivated, score: entry.score, trace: trace}
            {result, put_in(state.transitions[entry.id], tick)}

          {:error, reason} ->
            {%{region_id: entry.id, action: :kept_live, score: entry.score, error: reason}, state}
        end

      {resolution, :live} when resolution in [:coarse, :inert] ->
        seed = :erlang.phash2({:automatic_resolution, entry.id, tick})

        case RegionActivationLifecycle.activate(entry.id, seed, opts, state.lifecycle_server) do
          {:ok, trace} ->
            result = %{region_id: entry.id, action: :activated, score: entry.score, trace: trace}
            {result, put_in(state.transitions[entry.id], tick)}

          {:error, reason} ->
            {%{region_id: entry.id, action: :kept_compressed, score: entry.score, error: reason}, state}
        end

      _ ->
        action = if entry.current == :live, do: :kept_live, else: :kept_compressed
        {%{region_id: entry.id, action: action, score: entry.score}, state}
    end
  end

  defp active_player_presence?(observation, tick, opts) do
    observed_tick = Map.get(observation, :last_observed_tick, tick)
    age = max(tick - observed_tick, 0)
    ttl = max(Keyword.get(opts, :player_presence_ttl, 2), 0)
    truthy?(observation, :player_present) and age <= ttl
  end

  defp number(map, key, default) do
    case Map.get(map, key, default) do
      value when is_number(value) -> value * 1.0
      _ -> default * 1.0
    end
  end

  defp truthy?(map, key), do: Map.get(map, key, false) == true
  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end
