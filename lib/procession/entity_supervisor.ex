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

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
