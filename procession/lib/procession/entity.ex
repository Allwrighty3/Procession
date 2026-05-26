defmodule Procession.Entity do
  use GenServer

  defstruct [
    :id,
    :name,
    :type,
    :location,
    short_memory: [],
    medium_memory: [],
    long_memory: [],
    traits: %{},
    status: :idle
  ]

  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    state = Keyword.fetch!(opts, :state)

    GenServer.start_link(__MODULE__, state, name: via_tuple(id))
  end

  def send_message(id, message) do
    GenServer.cast(via_tuple(id), {:message, message})
  end

  def get_state(id) do
    GenServer.call(via_tuple(id), :get_state)
  end

  @impl true
  def init(state) do
    {:ok, struct(__MODULE__, state)}
  end

  @impl true
  def handle_cast({:message, message}, state) do
    updated_memory =
      [message | state.short_memory]
      |> Enum.take(10)

    {:noreply, %{state | short_memory: updated_memory}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp via_tuple(id) do
    {:via, Registry, {Procession.EntityRegistry, id}}
  end
end
