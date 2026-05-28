defmodule Procession.Entity do
  use GenServer

  @moduledoc """
  A single world entity process.

  Each entity is a GenServer registered by ID through `Procession.EntityRegistry`.
  Entities can receive messages, store those messages as memories, update basic
  state, and expose recall APIs.

  Most external code should start entities through `Procession.EntitySupervisor`.
  """

  defstruct [
    :id,
    :name,
    :type,
    :location,
    short_memory: [],
    medium_memory: [],
    long_memory: [],
    traits: %{},
    metadata: %{},
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

  def set_trait(id, trait, value) do
    GenServer.call(via_tuple(id), {:set_trait, trait, value})
  end

  def set_metadata(id, key, value) do
    GenServer.call(via_tuple(id), {:set_metadata, key, value})
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

  def recall_by_type(id, type) do
    GenServer.call(via_tuple(id), {:recall_by_type, type})
  end

  def recall_recent(id, count) do
    GenServer.call(via_tuple(id), {:recall_recent, count})
  end

  def recall_important(id, minimum_importance) do
    GenServer.call(via_tuple(id), {:recall_important, minimum_importance})
  end

  def recall_by_sender(id, sender) do
    GenServer.call(via_tuple(id), {:recall_by_sender, sender})
  end

  def recall_by_tag(id, tag) do
    GenServer.call(via_tuple(id), {:recall_by_tag, tag})
  end

  def recall_by_metadata(id, key, value) do
    GenServer.call(via_tuple(id), {:recall_by_metadata, key, value})
  end

  def memory_summary(id) do
    GenServer.call(via_tuple(id), :memory_summary)
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
  def handle_call({:set_trait, trait, value}, _from, state) do
    updated_traits = Map.put(state.traits, trait, value)
    updated_state = %{state | traits: updated_traits}

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call({:set_metadata, key, value}, _from, state) do
    updated_metadata = Map.put(state.metadata, key, value)
    updated_state = %{state | metadata: updated_metadata}

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
  def handle_call(:memory_summary, _from, state) do
    summary = %{
      short: length(state.short_memory),
      medium: length(state.medium_memory),
      long: length(state.long_memory)
    }

    {:reply, summary, state}
  end

  @impl true
  def handle_call(:recall_all, _from, state) do
    {:reply, Procession.Memory.flatten(state), state}
  end

  @impl true
  def handle_call({:recall_by_type, type}, _from, state) do
    memories =
      state
      |> Procession.Memory.flatten()
      |> Procession.Memory.filter_by_type(type)

    {:reply, memories, state}
  end

  @impl true
  def handle_call({:recall_recent, count}, _from, state) do
    memories =
      state
      |> Procession.Memory.flatten()
      |> Procession.Memory.recent(count)

    {:reply, memories, state}
  end

  @impl true
  def handle_call({:recall_important, minimum_importance}, _from, state) do
    memories =
      state
      |> Procession.Memory.flatten()
      |> Procession.Memory.important(minimum_importance)

    {:reply, memories, state}
  end

  @impl true
  def handle_call({:recall_by_sender, sender}, _from, state) do
    memories =
      state
      |> Procession.Memory.flatten()
      |> Procession.Memory.filter_by_sender(sender)

    {:reply, memories, state}
  end

  @impl true
  def handle_call({:recall_by_tag, tag}, _from, state) do
    memories =
      state
      |> Procession.Memory.flatten()
      |> Procession.Memory.filter_by_tag(tag)

    {:reply, memories, state}
  end

  @impl true
  def handle_call({:recall_by_metadata, key, value}, _from, state) do
    memories =
      state
      |> Procession.Memory.flatten()
      |> Procession.Memory.filter_by_metadata(key, value)

    {:reply, memories, state}
  end
end
