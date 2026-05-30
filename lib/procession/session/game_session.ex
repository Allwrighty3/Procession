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

  @doc """
  Returns the active entity IDs owned by this session.
  """
  def active_entities(session) do
    GenServer.call(session, :active_entities)
  end

  @doc """
  Returns whether the given entity ID belongs to this session.
  """
  def owns_entity?(session, entity_id) when is_binary(entity_id) do
    GenServer.call(session, {:owns_entity?, entity_id})
  end

  def owns_entity?(_session, _entity_id), do: false

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

  @impl true
  def handle_call(:active_entities, _from, state) do
    {:reply, state.active_entities, state}
  end

  @impl true
  def handle_call({:owns_entity?, entity_id}, _from, state) do
    {:reply, entity_id in state.active_entities, state}
  end
end
