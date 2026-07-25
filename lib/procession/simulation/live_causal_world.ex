defmodule Procession.Simulation.LiveCausalWorld do
  use GenServer

  @moduledoc """
  OTP owner for one active authoritative causal world.

  This process owns physical world truth only. Each entity-associated
  `LiveSensorimotor` process remains the sole owner of that entity's mental and
  motor state. A tick coordinates a two-phase handshake: entity emission, world
  resolution, then grounded feedback.
  """

  alias Procession.EntitySupervisor
  alias Procession.Simulation.CausalWorldKernel
  alias Procession.Simulation.LiveSensorimotor

  @name __MODULE__

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    kernel_opts = Keyword.get(opts, :kernel_opts, [])
    GenServer.start_link(__MODULE__, kernel_opts, name: name)
  end

  def tick, do: tick(@name, [])
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
      {:ok, updated} -> {:reply, {:ok, trace_with_minds(updated)}, updated}
      {:error, reason, unchanged} -> {:reply, {:error, reason}, unchanged}
    end
  end

  def handle_call({:run, ticks, opts}, _from, state)
      when is_integer(ticks) and ticks >= 0 do
    result =
      Enum.reduce_while(1..ticks, {:ok, state}, fn _, {:ok, current} ->
        case advance_tick(current, opts) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          {:error, reason, unchanged} -> {:halt, {:error, reason, unchanged}}
        end
      end)

    case {ticks, result} do
      {0, _} -> {:reply, {:ok, trace_with_minds(state)}, state}
      {_, {:ok, updated}} -> {:reply, {:ok, trace_with_minds(updated)}, updated}
      {_, {:error, reason, unchanged}} -> {:reply, {:error, reason}, unchanged}
    end
  end

  def handle_call({:run, _ticks, _opts}, _from, state) do
    {:reply, {:error, :invalid_tick_count}, state}
  end

  def handle_call(:trace, _from, state), do: {:reply, trace_with_minds(state), state}
  def handle_call(:state, _from, state), do: {:reply, state, state}

  defp advance_tick(state, opts) do
    started = CausalWorldKernel.begin_tick(state)

    result =
      started
      |> CausalWorldKernel.entity_ids()
      |> Enum.reduce_while({:ok, started}, fn entity_id, {:ok, world} ->
        with :ok <- validate_entity(entity_id),
             features <- CausalWorldKernel.perceive(world, entity_id),
             {:ok, emission} <- LiveSensorimotor.emit(entity_id, features, world.tick, opts),
             {resolved_world, resolution} <-
               CausalWorldKernel.resolve(
                 world,
                 entity_id,
                 emission.outcome,
                 emission.proposed_position,
                 opts
               ),
             {:ok, _trace} <-
               LiveSensorimotor.resolve(
                 entity_id,
                 resolution.position,
                 resolution.feedback_features,
                 resolution.coherence,
                 opts
               ) do
          {:cont, {:ok, resolved_world}}
        else
          {:error, reason} -> {:halt, {:error, {entity_id, reason}, state}}
        end
      end)

    case result do
      {:ok, world} -> {:ok, CausalWorldKernel.finish_tick(world)}
      {:error, reason, unchanged} -> {:error, reason, unchanged}
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

  defp trace_with_minds(state) do
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

    %{physical | entities: entities}
  end
end
