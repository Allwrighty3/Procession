defmodule Procession.EntitySupervisor do
  use DynamicSupervisor

  alias Procession.Entity
  alias Procession.Simulation.LiveSensorimotor

  @moduledoc """
  Dynamic supervisor for entity processes and their optional live subsystems.

  Entity IDs are registered through `Procession.EntityRegistry`. Sensorimotor owners
  are opt-in and registered under a private composite key tied to the entity ID.
  """

  def start_link(_opts), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc """
  Starts a new entity process registered by its ID.

  Pass `sensorimotor: keyword_options` in attrs to attach a developmental owner.
  The options may include `snapshot:` for a bounded dormant snapshot or `loop:` for
  an exact short-lived rollback checkpoint. These options are consumed by the
  supervisor and are not exposed as entity metadata.
  """
  def start_entity(id, attrs) do
    {sensorimotor_opts, entity_attrs} = Map.pop(attrs, :sensorimotor)

    case start_entity_process(id, entity_attrs) do
      {:ok, entity_pid} ->
        case maybe_start_sensorimotor(id, entity_pid, sensorimotor_opts) do
          :ok -> {:ok, entity_pid}
          {:error, reason} ->
            DynamicSupervisor.terminate_child(__MODULE__, entity_pid)
            {:error, reason}
        end

      error -> error
    end
  end

  def start_player(id, attrs \\ %{}), do: start_entity(id, Map.put(attrs, :type, :player))
  def start_npc(id, attrs \\ %{}), do: start_entity(id, Map.put(attrs, :type, :npc))
  def start_location(id, attrs \\ %{}), do: start_entity(id, Map.put(attrs, :type, :location))
  def start_faction(id, attrs \\ %{}), do: start_entity(id, Map.put(attrs, :type, :faction))

  def enable_sensorimotor(id, opts \\ []) when is_list(opts) do
    case lookup_entity(id) do
      {:ok, entity_pid} ->
        case Registry.lookup(Procession.EntityRegistry, {:sensorimotor, id}) do
          [{pid, _value}] -> {:error, {:already_started, pid}}
          [] -> start_sensorimotor(id, entity_pid, opts)
        end

      {:error, :not_found} -> {:error, :entity_not_found}
    end
  end

  def sensorimotor_enabled?(id),
    do: match?([{_pid, _value}], Registry.lookup(Procession.EntityRegistry, {:sensorimotor, id}))

  def sensorimotor_cycle(id, features, tick, feedback_fun, opts \\ []) do
    with :ok <- require_sensorimotor(id), do: LiveSensorimotor.cycle(id, features, tick, feedback_fun, opts)
  end

  def sensorimotor_observe(id, features, opts \\ []) do
    with :ok <- require_sensorimotor(id), do: LiveSensorimotor.observe(id, features, opts)
  end

  def sensorimotor_emit(id, features, tick, opts \\ []) do
    with :ok <- require_sensorimotor(id), do: LiveSensorimotor.emit(id, features, tick, opts)
  end

  def sensorimotor_resolve(id, position, features, coherence, opts \\ []) do
    with :ok <- require_sensorimotor(id), do: LiveSensorimotor.resolve(id, position, features, coherence, opts)
  end

  def sensorimotor_feedback(id, features, coherence, opts \\ []) do
    with :ok <- require_sensorimotor(id), do: LiveSensorimotor.feedback(id, features, coherence, opts)
  end

  def sensorimotor_snapshot(id, opts \\ []) do
    with :ok <- require_sensorimotor(id), do: LiveSensorimotor.snapshot(id, opts)
  end

  def sensorimotor_checkpoint(id) do
    with :ok <- require_sensorimotor(id), do: LiveSensorimotor.checkpoint(id)
  end

  def sensorimotor_trace(id) do
    if sensorimotor_enabled?(id), do: {:ok, LiveSensorimotor.trace(id)}, else: {:error, :sensorimotor_not_enabled}
  end

  def exists?(id), do: match?([{_pid, _value}], Registry.lookup(Procession.EntityRegistry, id))

  def stop_entity(id) do
    stop_sensorimotor(id)

    case Registry.lookup(Procession.EntityRegistry, id) do
      [{pid, _value}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  def lookup_entity(id) do
    case Registry.lookup(Procession.EntityRegistry, id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def list_entities do
    Procession.EntityRegistry
    |> Registry.select([{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.reject(fn {id, _pid} -> match?({:sensorimotor, _}, id) end)
  end

  def create_npc(attrs \\ %{}) do
    id = Procession.Id.npc()
    case start_npc(id, attrs) do
      {:ok, pid} -> {:ok, id, pid}
      error -> error
    end
  end

  def create_location(attrs \\ %{}) do
    id = Procession.Id.location()
    case start_location(id, attrs) do
      {:ok, pid} -> {:ok, id, pid}
      error -> error
    end
  end

  def create_faction(attrs \\ %{}) do
    id = Procession.Id.faction()
    case start_faction(id, attrs) do
      {:ok, pid} -> {:ok, id, pid}
      error -> error
    end
  end

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  defp start_entity_process(id, attrs) do
    child_spec = {Entity, id: id, state: Map.put(attrs, :id, id)}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  defp maybe_start_sensorimotor(_id, _entity_pid, nil), do: :ok

  defp maybe_start_sensorimotor(id, entity_pid, opts) when is_list(opts) do
    case start_sensorimotor(id, entity_pid, opts) do
      {:ok, _pid} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_sensorimotor(id, entity_pid, opts) do
    child_opts =
      [entity_id: id, owner_pid: entity_pid]
      |> maybe_put(:snapshot, Keyword.get(opts, :snapshot))
      |> maybe_put(:loop, Keyword.get(opts, :loop))
      |> Keyword.put(:loop_opts, Keyword.drop(opts, [:snapshot, :loop]))

    DynamicSupervisor.start_child(__MODULE__, {LiveSensorimotor, child_opts})
  end

  defp stop_sensorimotor(id) do
    case Registry.lookup(Procession.EntityRegistry, {:sensorimotor, id}) do
      [{pid, _value}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end

  defp require_sensorimotor(id) do
    if sensorimotor_enabled?(id), do: :ok, else: {:error, :sensorimotor_not_enabled}
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end