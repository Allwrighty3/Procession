defmodule Procession.Simulation.RegionObservationPublisher do
  use GenServer

  @moduledoc """
  Aggregates grounded regional evidence and publishes bounded observations to the
  automatic resolution policy.

  Live entity location and sensorimotor salience are sampled from their authoritative
  OTP owners. Physical/social subsystems may publish transient regional events and
  cross-region dependency pressure. The publisher owns only aggregation state; it does
  not own regions, entities, minds, or resolution decisions.
  """

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.AutomaticResolutionPolicy

  @name __MODULE__

  def start_link(opts \\ []) do
    state = %{
      events: %{},
      dependencies: %{},
      region_positions: %{},
      policy_server: Keyword.get(opts, :policy_server, AutomaticResolutionPolicy),
      entity_supervisor: Keyword.get(opts, :entity_supervisor, EntitySupervisor),
      config: Keyword.get(opts, :config, [])
    }

    GenServer.start_link(__MODULE__, state, name: Keyword.get(opts, :name, @name))
  end

  def publish_event(region_id, intensity, tick, server \\ @name)
      when is_number(intensity) and is_integer(tick),
      do: GenServer.call(server, {:event, region_id, intensity, tick})

  def publish_dependency(from_region, to_region, pressure, tick, server \\ @name)
      when is_number(pressure) and is_integer(tick),
      do: GenServer.call(server, {:dependency, from_region, to_region, pressure, tick})

  def set_region_position(region_id, {x, y} = position, server \\ @name)
      when is_number(x) and is_number(y),
      do: GenServer.call(server, {:region_position, region_id, position})

  def clear_dependency(from_region, to_region, server \\ @name),
    do: GenServer.call(server, {:clear_dependency, from_region, to_region})

  def refresh(tick, opts \\ [], server \\ @name) when is_integer(tick),
    do: GenServer.call(server, {:refresh, tick, opts}, :infinity)

  def trace(server \\ @name), do: GenServer.call(server, :trace)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:event, region_id, intensity, tick}, _from, state) do
    event = %{intensity: clamp(intensity * 1.0, 0.0, 1.0), tick: tick}
    {:reply, :ok, put_in(state.events[region_id], event)}
  end

  def handle_call({:dependency, from, to, pressure, tick}, _from, state) do
    dependency = %{pressure: clamp(pressure * 1.0, 0.0, 1.0), tick: tick}
    {:reply, :ok, put_in(state.dependencies[{from, to}], dependency)}
  end

  def handle_call({:clear_dependency, from, to}, _from, state) do
    {:reply, :ok, %{state | dependencies: Map.delete(state.dependencies, {from, to})}}
  end

  def handle_call({:region_position, region_id, position}, _from, state) do
    {:reply, :ok, put_in(state.region_positions[region_id], position)}
  end

  def handle_call({:refresh, tick, opts}, _from, state) do
    effective = Keyword.merge(state.config, opts)
    {observations, updated} = build_observations(state, tick, effective)

    results =
      Enum.map(observations, fn {region_id, observation} ->
        {region_id, AutomaticResolutionPolicy.observe(region_id, observation, state.policy_server)}
      end)

    {:reply, %{tick: tick, published: Map.new(observations), results: Map.new(results)}, updated}
  end

  def handle_call(:trace, _from, state) do
    {:reply,
     %{
       events: state.events,
       dependencies: state.dependencies,
       region_positions: state.region_positions
     }, state}
  end

  defp build_observations(state, tick, opts) do
    event_ttl = max(Keyword.get(opts, :regional_event_ttl, 80), 0)
    dependency_ttl = max(Keyword.get(opts, :regional_dependency_ttl, 240), 0)
    events = retain_recent(state.events, tick, event_ttl)
    dependencies = retain_recent(state.dependencies, tick, dependency_ttl)
    entity_samples = sample_entities(state.entity_supervisor)
    players = Enum.filter(entity_samples, &(&1.type == :player and not is_nil(&1.location)))
    grouped = Enum.group_by(entity_samples, & &1.location)
    regions = known_regions(grouped, events, dependencies)

    observations =
      Map.new(regions, fn region_id ->
        residents = Map.get(grouped, region_id, [])
        player_present = Enum.any?(players, &(&1.location == region_id))
        distance = player_distance(region_id, players, state.region_positions)
        salience = aggregate_salience(residents)
        dependency = dependency_pressure(region_id, dependencies)
        event = Map.get(events, region_id, %{intensity: 0.0, tick: tick})

        observation = %{
          player_present: player_present,
          distance: distance,
          unresolved_dependencies: dependency,
          salience: salience,
          event_intensity: event.intensity,
          last_observed_tick: tick,
          evidence: %{
            resident_count: length(residents),
            sampled_minds: Enum.count(residents, & &1.mind_sampled?),
            event_tick: event.tick
          }
        }

        {region_id, observation}
      end)

    {observations, %{state | events: events, dependencies: dependencies}}
  end

  defp sample_entities(supervisor) do
    supervisor.list_entities()
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
    |> Enum.flat_map(fn id ->
      try do
        entity = Entity.get_state(id)
        salience = sample_salience(supervisor, id)

        [
          %{
            id: id,
            type: entity.type,
            location: entity.location,
            salience: salience,
            mind_sampled?: not is_nil(salience)
          }
        ]
      catch
        :exit, _reason -> []
      end
    end)
  end

  defp sample_salience(supervisor, id) do
    case supervisor.sensorimotor_trace(id) do
      {:ok, %{salience: salience}} when is_map(salience) ->
        active = number(salience, :active_mass, 0.0)
        imprints = number(salience, :imprint_count, 0.0)

        effective =
          salience
          |> Map.get(:effective_signals, %{})
          |> Map.values()
          |> Enum.map(&abs/1)
          |> Enum.max(fn -> 0.0 end)

        clamp(max(effective, active / 10.0) + min(imprints * 0.05, 0.35), 0.0, 1.0)

      _ ->
        nil
    end
  end

  defp aggregate_salience(residents) do
    values = residents |> Enum.map(& &1.salience) |> Enum.reject(&is_nil/1)

    case values do
      [] ->
        0.0

      _ ->
        mean = Enum.sum(values) / length(values)
        peak = Enum.max(values)
        clamp(max(mean, peak * 0.75), 0.0, 1.0)
    end
  end

  defp known_regions(grouped, events, dependencies) do
    dependency_regions =
      dependencies
      |> Map.keys()
      |> Enum.flat_map(fn {from, to} -> [from, to] end)

    Map.keys(grouped)
    |> Enum.concat(Map.keys(events))
    |> Enum.concat(dependency_regions)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp player_distance(region_id, players, positions) do
    cond do
      Enum.any?(players, &(&1.location == region_id)) ->
        0.0

      Map.has_key?(positions, region_id) ->
        players
        |> Enum.map(&Map.get(positions, &1.location))
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&euclidean(Map.fetch!(positions, region_id), &1))
        |> Enum.min(fn -> 1.0e6 end)

      true ->
        1.0e6
    end
  end

  defp dependency_pressure(region_id, dependencies) do
    dependencies
    |> Enum.reduce(0.0, fn
      {{^region_id, _to}, dependency}, total -> max(total, dependency.pressure)
      {{_from, ^region_id}, dependency}, total -> max(total, dependency.pressure)
      _, total -> total
    end)
  end

  defp retain_recent(entries, tick, ttl) do
    entries
    |> Enum.filter(fn {_key, value} -> tick - value.tick <= ttl end)
    |> Map.new()
  end

  defp euclidean({x1, y1}, {x2, y2}),
    do: :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))

  defp number(map, key, default),
    do: if(is_number(Map.get(map, key)), do: Map.get(map, key) * 1.0, else: default)

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end
