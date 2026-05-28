defmodule Procession.EntitySupervisor do
  use DynamicSupervisor

  alias Procession.Entity

  @moduledoc """
  Dynamic supervisor for entity processes.

  Provides public APIs for starting, stopping, checking, looking up, and listing
  entities. Entity IDs are registered through `Procession.EntityRegistry`.
  """

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

  def start_npc(id, attrs \\ %{}) do
    start_entity(id, Map.put(attrs, :type, :npc))
  end

  def start_location(id, attrs \\ %{}) do
    start_entity(id, Map.put(attrs, :type, :location))
  end

  def start_faction(id, attrs \\ %{}) do
    start_entity(id, Map.put(attrs, :type, :faction))
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
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
