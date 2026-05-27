defmodule Procession.EntitySupervisor do
  use DynamicSupervisor

  alias Procession.Entity

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

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

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
