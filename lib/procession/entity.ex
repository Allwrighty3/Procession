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
    if Procession.EntitySupervisor.exists?(to_id) do
      full_message =
        message
        |> Map.put(:from, from_id)
        |> Map.put_new(:type, :message)

      send_message(to_id, full_message)
    else
      {:error, :entity_not_found}
    end
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

  def recall(id, query) do
    GenServer.call(via_tuple(id), {:recall, query})
  end

  def recall_all(id) do
    GenServer.call(via_tuple(id), :recall_all)
  end

  def via_tuple(id) do
    {:via, Registry, {Procession.EntityRegistry, id}}
  end

  @impl true
  def init(state) do
    {:ok, struct(__MODULE__, state)}
  end

  @impl true
  def handle_cast({:message, message}, state) do
    memory_entry = Procession.Memory.from_message(message)

    {updated_short_memory, short_overflow} =
      Procession.Memory.remember_short_with_overflow(state.short_memory, memory_entry)

    {updated_medium_memory, medium_overflow} =
      Enum.reduce(short_overflow, {state.medium_memory, []}, fn memory,
                                                                {medium_memory, all_overflow} ->
        {updated_medium, overflow} =
          Procession.Memory.remember_medium_with_overflow(medium_memory, memory)

        {updated_medium, all_overflow ++ overflow}
      end)

    updated_long_memory =
      Enum.reduce(medium_overflow, state.long_memory, fn memory, long_memory ->
        Procession.Memory.remember_long(long_memory, memory)
      end)

    {:noreply,
     %{
       state
       | short_memory: updated_short_memory,
         medium_memory: updated_medium_memory,
         long_memory: updated_long_memory
     }}
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

  @impl true
  def handle_call({:recall, query}, _from, state) do
    memories =
      state
      |> Procession.Memory.flatten()
      |> Procession.Memory.search(query)

    {:reply, memories, state}
  end

  @impl true
  def handle_call(:recall_all, _from, state) do
    {:reply, Procession.Memory.flatten(state), state}
  end
end
