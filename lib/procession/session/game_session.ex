defmodule Procession.GameSession do
  @moduledoc """
  Runtime session boundary for tracking active game state and session-owned entities.

  A game session owns the live entity IDs associated with one active play session.
  It does not own generation, entity behavior execution, or world ticking.
  """

  use GenServer

  alias Procession.Id
  alias Procession.Game

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

  @doc """
  Creates a deterministic game through the session and tracks the generated entities.
  """
  def new_game(session, prompt) do
    GenServer.call(session, {:new_game, prompt})
  end

  defp extract_entity_ids(game_summary) do
    game_summary
    |> Map.take([:locations, :npcs, :factions])
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
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

  @impl true
  def handle_call({:new_game, prompt}, _from, state) do
    case Game.new_game(prompt) do
      {:ok, game_summary} ->
        active_entities = extract_entity_ids(game_summary)

        new_state = %{
          state
          | world: game_summary,
            active_entities: active_entities,
            status: :active
        }

        {:reply, {:ok, Map.from_struct(new_state)}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
end
