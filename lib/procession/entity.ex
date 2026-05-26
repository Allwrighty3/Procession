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

  def send_to(from_id, to_id, message) do
    full_message =
      message
      |> Map.put(:from, from_id)
      |> Map.put_new(:type, :message)

    send_message(to_id, full_message)
  end

  def get_state(id) do
    GenServer.call(via_tuple(id), :get_state)
  end

  def describe(id) do
    GenServer.call(via_tuple(id), :describe)
  end

  def set_status(id, status) do
    GenServer.call(via_tuple(id), {:set_status, status})
  end

  def move_to(id, location) do
    GenServer.call(via_tuple(id), {:move_to, location})
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

  @impl true
  def handle_call(:describe, _from, state) do
    description = %{
      id: state.id,
      name: state.name,
      type: state.type,
      location: state.location,
      status: state.status
    }

    {:reply, description, state}
  end

  @impl true
  def handle_call({:set_status, status}, _from, state) do
    updated_state = %{state | status: status}
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:move_to, location}, _from, state) do
    updated_state = %{state | location: location}
    {:reply, :ok, updated_state}
  end

  defp via_tuple(id) do
    {:via, Registry, {Procession.EntityRegistry, id}}
  end
end
