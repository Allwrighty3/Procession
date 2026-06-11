defmodule Procession.Simulation.InternalFieldProcess do
  use GenServer

  alias Procession.Simulation.InternalField

  def start_link(opts) do
    entity_id = Keyword.fetch!(opts, :entity_id)
    name = Keyword.get(opts, :name)

    genserver_opts =
      if name do
        [name: name]
      else
        []
      end

    GenServer.start_link(__MODULE__, entity_id, genserver_opts)
  end

  def apply_presentation(server, presentation) when is_map(presentation) do
    GenServer.call(server, {:apply_presentation, presentation})
  end

  def snapshot(server) do
    GenServer.call(server, :snapshot)
  end

  @impl true
  def init(entity_id) do
    {:ok, InternalField.new(entity_id)}
  end

  @impl true
  def handle_call({:apply_presentation, presentation}, _from, field) do
    updated_field = InternalField.apply_presentation(field, presentation)

    {:reply, {:ok, InternalField.snapshot(updated_field)}, updated_field}
  end

  @impl true
  def handle_call(:snapshot, _from, field) do
    {:reply, InternalField.snapshot(field), field}
  end
end
