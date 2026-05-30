defmodule Procession.GameSession do
  @moduledoc """
  Runtime session boundary for tracking active game state and session-owned entities.

  A game session owns the live entity IDs associated with one active play session.
  It does not own generation, entity behavior execution, or world ticking.
  """

  use GenServer

  alias Procession.Id
  alias Procession.Game
  alias Procession.EntitySupervisor
  alias Procession.Entity

  defstruct [
    :player_id,
    :session_id,
    :world,
    :active_scope,
    status: :new,
    active_entities: [],
    last_tick_summary: nil
  ]

  @type status :: :new | :active | :cleaned_up

  @type t :: %__MODULE__{
          player_id: String.t() | nil,
          session_id: String.t(),
          world: map() | nil,
          active_entities: [String.t()],
          active_scope: String.t() | nil,
          status: status(),
          last_tick_summary: map() | nil
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

  @doc """
  Stops all live entities owned by this session and marks the session as cleaned up.
  """
  def cleanup(session) do
    GenServer.call(session, :cleanup)
  end

  @doc """
  Look at a session-owned entity.

  Returns `{:error, :entity_not_in_session}` when the entity does not belong
  to this session.
  """
  def look(session, entity_id) when is_binary(entity_id) do
    GenServer.call(session, {:look, entity_id})
  end

  def look(_session, _entity_id), do: {:error, :entity_not_in_session}

  @doc """
  Asks about memories for a session-owned entity.

  Returns `{:error, :entity_not_in_session}` when the entity does not belong
  to this session.
  """
  def ask_about(session, entity_id, topic) when is_binary(entity_id) do
    GenServer.call(session, {:ask_about, entity_id, topic})
  end

  def ask_about(_session, _entity_id, _topic), do: {:error, :entity_not_in_session}

  @doc """
  Talks to a session-owned NPC.

  Returns `{:error, :entity_not_in_session}` when the entity does not belong
  to this session.
  """
  def talk_to(session, entity_id, message, opts \\ []) when is_binary(entity_id) do
    GenServer.call(session, {:talk_to, entity_id, message, opts})
  end

  def talk_to(_session, _entity_id, _message, _opts), do: {:error, :entity_not_in_session}

  @doc """
  Returns recent events for a session-owned entity.

  Returns `{:error, :entity_not_in_session}` when the entity does not belong
  to this session.
  """
  def recent_events(session, entity_id) when is_binary(entity_id) do
    GenServer.call(session, {:recent_events, entity_id})
  end

  def recent_events(_session, _entity_id), do: {:error, :entity_not_in_session}

  @doc """
  Ticks the world through this session.

  The first Phase 9 version delegates to `Procession.Game.tick_world/0`.
  It is not yet scoped to session-owned entities.
  """
  def tick(session) do
    GenServer.call(session, :tick)
  end

  @doc """
  Performs a session-aware gameplay action.

  This is not text command parsing. Actions are atoms and arguments are keyword options.
  """
  def perform(session, action, opts \\ []) when is_atom(action) and is_list(opts) do
    case action do
      :look ->
        with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target) do
          look(session, entity_id)
        end

      :ask_about ->
        with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target),
             {:ok, topic} <- fetch_required_opt(opts, :topic, :missing_topic) do
          ask_about(session, entity_id, topic)
        end

      :talk_to ->
        with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target),
             {:ok, message} <- fetch_required_opt(opts, :message, :missing_message) do
          ai_opts = Keyword.drop(opts, [:entity_id, :message])
          talk_to(session, entity_id, message, ai_opts)
        end

      :recent_events ->
        with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target) do
          recent_events(session, entity_id)
        end

      :tick ->
        tick(session)

      _ ->
        {:error, :invalid_action}
    end
  end

  def perform(_session, _action, _opts), do: {:error, :invalid_action}

  @doc """
  Returns the current player entity ID for this session.
  """
  def player(session) do
    GenServer.call(session, :player)
  end

  @doc """
  Returns the current player location for this session.
  """
  def player_location(session) do
    GenServer.call(session, :player_location)
  end

  defp extract_entity_ids(game_summary) do
    game_summary
    |> Map.take([:locations, :npcs, :factions])
    |> Map.values()
    |> List.flatten()
    |> Enum.uniq()
  end

  defp build_summary(state) do
    %{
      player_id: state.player_id,
      session_id: state.session_id,
      status: state.status,
      world: state.world,
      world_name: world_name(state.world),
      active_scope: state.active_scope,
      active_entities: state.active_entities,
      active_entity_count: length(state.active_entities),
      last_tick_summary: state.last_tick_summary
    }
  end

  defp world_name(nil), do: nil
  defp world_name(world), do: Map.get(world, :name)

  defp fetch_required_opt(opts, key, error_reason) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, error_reason}
    end
  end

  defp first_location_id(game_summary) do
    game_summary
    |> Map.get(:locations, [])
    |> List.first()
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
    {:reply, build_summary(state), state}
  end

  @impl true
  def handle_call({:new_game, prompt}, _from, state) do
    case Game.new_game(prompt) do
      {:ok, game_summary} ->
        player_id = "player_main"

        case EntitySupervisor.start_player(player_id, %{
               name: "Player",
               location: first_location_id(game_summary),
               status: :idle,
               metadata: %{session_id: state.session_id}
             }) do
          {:ok, _pid} ->
            active_entities =
              game_summary
              |> extract_entity_ids()
              |> then(fn entity_ids -> [player_id | entity_ids] end)
              |> Enum.uniq()

            new_state = %{
              state
              | world: game_summary,
                player_id: player_id,
                active_entities: active_entities,
                status: :active
            }

            {:reply, {:ok, build_summary(new_state)}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

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

  @impl true
  def handle_call(:cleanup, _from, state) do
    cleanup_summary =
      Enum.reduce(state.active_entities, %{stopped: [], missing: []}, fn entity_id, acc ->
        case EntitySupervisor.stop_entity(entity_id) do
          :ok ->
            %{acc | stopped: [entity_id | acc.stopped]}

          {:error, :not_found} ->
            %{acc | missing: [entity_id | acc.missing]}
        end
      end)

    cleanup_summary = %{
      stopped: Enum.reverse(cleanup_summary.stopped),
      missing: Enum.reverse(cleanup_summary.missing),
      status: :cleaned_up
    }

    new_state = %{state | status: :cleaned_up}

    {:reply, cleanup_summary, new_state}
  end

  @impl true
  def handle_call({:look, entity_id}, _from, state) do
    if entity_id in state.active_entities do
      {:reply, Game.look(entity_id), state}
    else
      {:reply, {:error, :entity_not_in_session}, state}
    end
  end

  @impl true
  def handle_call({:ask_about, entity_id, topic}, _from, state) do
    if entity_id in state.active_entities do
      {:reply, Game.ask_about(entity_id, topic), state}
    else
      {:reply, {:error, :entity_not_in_session}, state}
    end
  end

  @impl true
  def handle_call({:talk_to, entity_id, message, opts}, _from, state) do
    if entity_id in state.active_entities do
      {:reply, Game.talk_to(entity_id, message, opts), state}
    else
      {:reply, {:error, :entity_not_in_session}, state}
    end
  end

  @impl true
  def handle_call({:recent_events, entity_id}, _from, state) do
    if entity_id in state.active_entities do
      {:reply, Game.recent_events(entity_id), state}
    else
      {:reply, {:error, :entity_not_in_session}, state}
    end
  end

  @impl true
  def handle_call(:tick, _from, state) do
    case Game.tick_world() do
      {:ok, tick_summary} ->
        new_state = %{state | last_tick_summary: tick_summary}
        {:reply, {:ok, tick_summary}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:player, _from, state) do
    {:reply, state.player_id, state}
  end

  @impl true
  def handle_call(:player_location, _from, %{player_id: nil} = state) do
    {:reply, {:error, :player_not_found}, state}
  end

  @impl true
  def handle_call(:player_location, _from, state) do
    if EntitySupervisor.exists?(state.player_id) do
      try do
        player_state = Entity.get_state(state.player_id)

        {:reply, {:ok, player_state.location}, state}
      catch
        :exit, _reason ->
          {:reply, {:error, :entity_not_found}, state}
      end
    else
      {:reply, {:error, :entity_not_found}, state}
    end
  end
end
