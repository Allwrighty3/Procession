defmodule Procession.Simulation.LiveCausalWorld do
  use GenServer

  @moduledoc """
  OTP owner for one active authoritative causal world.

  This process owns physical world truth only. Each entity-associated
  `LiveSensorimotor` process remains the sole owner of that entity's mental and
  motor state. A tick coordinates entity emission, world resolution, grounded
  feedback, and optional local observation through a separately owned social plane.
  """

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.CausalWorldKernel
  alias Procession.Simulation.LiveSocialPlane
  alias Procession.Simulation.RegionObservationPublisher
  alias Procession.Simulation.SocialRelationPlane

  @name __MODULE__

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    kernel_opts = Keyword.get(opts, :kernel_opts, [])
    GenServer.start_link(__MODULE__, kernel_opts, name: name)
  end

  def tick, do: tick(@name, [])
  def tick(opts) when is_list(opts), do: tick(@name, opts)
  def tick(server), do: tick(server, [])
  def tick(server, opts), do: GenServer.call(server, {:tick, opts}, :infinity)

  def run(ticks), do: run(@name, ticks, [])
  def run(server, ticks), do: run(server, ticks, [])
  def run(server, ticks, opts), do: GenServer.call(server, {:run, ticks, opts}, :infinity)

  def trace(server \\ @name), do: GenServer.call(server, :trace)
  def state(server \\ @name), do: GenServer.call(server, :state)

  def tick_if_running(opts \\ []) do
    case Process.whereis(@name) do
      nil -> {:ok, %{status: :skipped, reason: :causal_world_not_running}}
      pid -> tick(pid, opts)
    end
  end

  @impl true
  def init(kernel_opts), do: {:ok, CausalWorldKernel.new(kernel_opts)}

  @impl true
  def handle_call({:tick, opts}, _from, state) do
    case advance_tick(state, opts) do
      {:ok, updated} -> {:reply, {:ok, trace_with_planes(updated)}, updated}
      {:error, reason, updated} -> {:reply, {:error, reason}, updated}
    end
  end

  def handle_call({:run, 0, _opts}, _from, state) do
    {:reply, {:ok, trace_with_planes(state)}, state}
  end

  def handle_call({:run, ticks, opts}, _from, state)
      when is_integer(ticks) and ticks > 0 do
    result =
      Enum.reduce_while(1..ticks, {:ok, state}, fn _, {:ok, current} ->
        case advance_tick(current, opts) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          {:error, reason, updated} -> {:halt, {:error, reason, updated}}
        end
      end)

    case result do
      {:ok, updated} -> {:reply, {:ok, trace_with_planes(updated)}, updated}
      {:error, reason, updated} -> {:reply, {:error, reason}, updated}
    end
  end

  def handle_call({:run, _ticks, _opts}, _from, state) do
    {:reply, {:error, :invalid_tick_count}, state}
  end

  def handle_call(:trace, _from, state), do: {:reply, trace_with_planes(state), state}
  def handle_call(:state, _from, state), do: {:reply, state, state}

  defp advance_tick(state, opts) do
    started = CausalWorldKernel.begin_tick(state)
    advance_social_plane(started.tick, opts)

    result =
      started
      |> rotating_entity_order()
      |> Enum.reduce_while({:ok, started}, fn entity_id, {:ok, world} ->
        case advance_entity(world, entity_id, opts) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          {:error, reason, updated} -> {:halt, {:error, reason, updated}}
        end
      end)

    case result do
      {:ok, world} -> {:ok, CausalWorldKernel.finish_tick(world)}
      {:error, reason, world} -> {:error, reason, CausalWorldKernel.finish_tick(world)}
    end
  end

  defp advance_entity(world, entity_id, opts) do
    with :ok <- validate_entity(entity_id),
         features <- CausalWorldKernel.perceive(world, entity_id),
         {:ok, emission} <- EntitySupervisor.sensorimotor_emit(entity_id, features, world.tick, opts) do
      {resolved_world, resolution} =
        CausalWorldKernel.resolve(
          world,
          entity_id,
          emission.outcome,
          emission.proposed_position,
          opts
        )

      publish_physical_event(entity_id, resolution.event, world.tick, opts)

      case EntitySupervisor.sensorimotor_resolve(
             entity_id,
             resolution.position,
             resolution.feedback_features,
             resolution.coherence,
             opts
           ) do
        {:ok, _trace} ->
          observe_social_event(resolved_world, resolution.event, opts)
          {:ok, resolved_world}

        {:error, reason} ->
          {:error, {entity_id, {:feedback_failed, reason}}, resolved_world}
      end
    else
      {:error, reason} -> {:error, {entity_id, reason}, world}
    end
  end

  defp publish_physical_event(entity_id, event, tick, opts) do
    publisher = Keyword.get(opts, :region_observation_publisher, RegionObservationPublisher)

    if publisher_running?(publisher) do
      try do
        case Entity.get_state(entity_id).location do
          nil -> :ok
          region_id ->
            intensity = SocialRelationPlane.event_intensity(event, opts)
            RegionObservationPublisher.publish_event(region_id, intensity, tick, publisher)
        end
      catch
        :exit, _reason -> :ok
      end
    end
  end

  defp publisher_running?(pid) when is_pid(pid), do: Process.alive?(pid)
  defp publisher_running?(name) when is_atom(name), do: not is_nil(Process.whereis(name))
  defp publisher_running?(_publisher), do: false

  defp observe_social_event(world, event, opts) do
    case Process.whereis(LiveSocialPlane) do
      nil ->
        :ok

      social_pid ->
        world
        |> local_observers(event.entity_id, opts)
        |> Enum.each(fn observer_id ->
          raw_signal = SocialRelationPlane.physical_observation_signal(event, opts)
          raw_feature = signal_feature(raw_signal)

          case EntitySupervisor.sensorimotor_observe(observer_id, [raw_signal], opts) do
            {:ok, observer_trace} ->
              observer_salience = effective_salience(observer_trace, raw_feature)
              social_opts = Keyword.put(opts, :observer_salience, observer_salience)

              with {:ok, signals, _social_trace} <-
                     LiveSocialPlane.observe(
                       social_pid,
                       observer_id,
                       event,
                       world.tick,
                       social_opts
                     ) do
                EntitySupervisor.sensorimotor_observe(observer_id, signals, opts)
              end

            {:error, _reason} ->
              :ok
          end
        end)
    end
  end

  defp effective_salience(observer_trace, raw_feature) do
    observer_trace
    |> get_in([:salience, :effective_signals])
    |> case do
      signals when is_map(signals) -> max(0.0, Map.get(signals, raw_feature, 0.0))
      _ -> 0.0
    end
  end

  defp signal_feature({:signal, feature, _magnitude}), do: feature
  defp signal_feature(feature), do: feature

  defp local_observers(world, actor_id, opts) do
    actor = Map.fetch!(world.entities, actor_id)
    radius = Keyword.get(opts, :social_observation_radius, world.perception_radius)

    world.entities
    |> Enum.filter(fn {observer_id, observer} ->
      observer_id != actor_id and manhattan(observer.position, actor.position) <= radius
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  defp rotating_entity_order(world) do
    ids = CausalWorldKernel.entity_ids(world)

    case ids do
      [] ->
        []

      _ ->
        offset = rem(max(world.tick - 1, 0), length(ids))
        {front, back} = Enum.split(ids, offset)
        back ++ front
    end
  end

  defp advance_social_plane(tick, opts) do
    case Process.whereis(LiveSocialPlane) do
      nil -> :ok
      pid -> LiveSocialPlane.advance(pid, tick, opts)
    end
  end

  defp validate_entity(entity_id) do
    cond do
      not EntitySupervisor.exists?(entity_id) -> {:error, :entity_not_found}
      not EntitySupervisor.sensorimotor_enabled?(entity_id) ->
        {:error, :sensorimotor_not_enabled}

      true ->
        :ok
    end
  end

  defp trace_with_planes(state) do
    physical = CausalWorldKernel.trace(state)

    entities =
      Map.new(physical.entities, fn {entity_id, attrs} ->
        sensorimotor =
          case EntitySupervisor.sensorimotor_trace(entity_id) do
            {:ok, trace} -> trace
            {:error, reason} -> %{status: :unavailable, reason: reason}
          end

        {entity_id, Map.put(attrs, :sensorimotor, sensorimotor)}
      end)

    social =
      case Process.whereis(LiveSocialPlane) do
        nil -> %{status: :skipped, reason: :social_plane_not_running}
        pid -> LiveSocialPlane.trace(pid)
      end

    physical
    |> Map.put(:entities, entities)
    |> Map.put(:social, social)
  end

  defp manhattan({ax, ay}, {bx, by}), do: abs(ax - bx) + abs(ay - by)
end
