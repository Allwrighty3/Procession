defmodule Procession.EntitySupervisor do
  use DynamicSupervisor

  alias Procession.Entity

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Starts a new entity process registered by its ID.

  If an entity with the same ID already exists, startup fails with
  `{:error, {:already_started, pid}}` and the existing entity is left unchanged.
  """
  def start_entity(id, attrs) do
    child_spec = {
      Entity,
      id: id, state: Map.put(attrs, :id, id)
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def exists?(id) do
    case Registry.lookup(Procession.EntityRegistry, id) do
      [{_pid, _value}] -> true
      [] -> false
    end
  end

  def stop_entity(id) do
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
    |> Enum.map(fn {id, pid} -> {id, pid} end)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
