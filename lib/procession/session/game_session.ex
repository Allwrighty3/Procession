defmodule Procession.GameSession do
  @module """
  Runtime session boundary for tracking active game state and session-owned entities.

  A game session owns the live entity IDs associated with one active play session.
  It does not own generation, entity behavior execution, or world ticking.
  """

  use GenServer

  alias Procession.Id

  defstruct [
    :session_id,
    :world,
    :active_scope,
    status: :new,
    active_entities: []
  ]

  @type status :: :new | :active | :cleaned_up

  @type t :: %__MODULE__{
          session_id: String.t(),
          world: map() | nil,
          active_entities: [String.t()],
          active_scope: String.t() | nil,
          status: status()
        }

  @doc """
  Starts a new game session process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Returns a plain-data summary of the current session state.
  """
  def summary(session) do
    GenServer.call(session, :summary)
  end

  @impl true
  def init(opts) do
    session_id = Keyword.get_lazy(opts, :session_id, fn -> Id.generate("session") end)

    state = %__MODULE__{
      session_id: session_id
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    {:reply, Map.from_struct(state), state}
  end
end
