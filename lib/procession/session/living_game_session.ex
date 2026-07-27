defmodule Procession.LivingGameSession do
  @moduledoc """
  Session-compatible owner joining the starter gameplay shell to one stateful Living Briar world.
  """

  use GenServer

  alias Procession.GameSession
  alias Procession.Simulation.LivingBriarRuntime

  defstruct [:session, :runtime, :startup]

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)
  def start(opts \\ []), do: GenServer.start(__MODULE__, opts)
  def physical_action(session, primitive, opts \\ []),
    do: GenServer.call(session, {:player_physical_action, primitive, opts})

  def start_demo(prompt \\ "a quiet frontier town", opts \\ []) do
    with {:ok, session} <- start(Keyword.put(opts, :prompt, prompt)),
         startup <- GenServer.call(session, :startup) do
      {:ok, Map.put(startup, :session, session)}
    end
  end

  @impl true
  def init(opts) do
    prompt = Keyword.get(opts, :prompt, "a quiet frontier town")
    runtime_opts = Keyword.take(opts, [:seed, :budget, :cadence])

    case GameSession.start_demo(prompt) do
      {:ok, startup} ->
        case LivingBriarRuntime.start_link(runtime_opts) do
          {:ok, runtime} ->
            player_id = GameSession.player(startup.session)

            with {:ok, location_id} <- GameSession.player_location(startup.session),
                 {:ok, _presence} <-
                   LivingBriarRuntime.set_player_location(runtime, player_id, location_id) do
              {:ok, %__MODULE__{session: startup.session, runtime: runtime, startup: startup}}
            else
              {:error, reason} ->
                stop_runtime(runtime)
                cleanup_inner_session(startup.session)
                {:stop, reason}
            end

          {:error, reason} ->
            cleanup_inner_session(startup.session)
            {:stop, reason}
        end

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:startup, _from, state), do: {:reply, state.startup, state}

  def handle_call(:tick, _from, state) do
    with {:ok, tick_summary} <- GameSession.tick(state.session),
         {:ok, observation} <- LivingBriarRuntime.step(state.runtime) do
      {:reply, {:ok, Map.put(tick_summary, :living_briar, observation)}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:player_physical_action, primitive, opts}, _from, state) do
    {:reply, LivingBriarRuntime.player_action(state.runtime, primitive, opts), state}
  end

  def handle_call(:summary, _from, state) do
    summary = GameSession.summary(state.session)
    living = LivingBriarRuntime.snapshot(state.runtime)
    {:reply, Map.put(summary, :living_briar, living), state}
  end

  def handle_call(:active_entities, _from, state), do:
    {:reply, GameSession.active_entities(state.session), state}

  def handle_call({:owns_entity?, entity_id}, _from, state), do:
    {:reply, GameSession.owns_entity?(state.session, entity_id), state}

  def handle_call(:cleanup, _from, state) do
    living_summary = safe_snapshot(state.runtime)
    stop_runtime(state.runtime)
    cleanup = GameSession.cleanup(state.session)
    stop_inner_session(state.session)
    {:reply, Map.put(cleanup, :living_briar, living_summary),
     %{state | runtime: nil, session: nil}}
  end

  def handle_call(:look, _from, state), do:
    {:reply, GameSession.look(state.session), state}

  def handle_call({:look, entity_id}, _from, state), do:
    {:reply, GameSession.look(state.session, entity_id), state}

  def handle_call({:ask_about, entity_id, topic}, _from, state), do:
    {:reply, GameSession.ask_about(state.session, entity_id, topic), state}

  def handle_call({:talk_to, entity_id, message, opts}, _from, state), do:
    {:reply, GameSession.talk_to(state.session, entity_id, message, opts), state}

  def handle_call({:recent_events, entity_id}, _from, state), do:
    {:reply, GameSession.recent_events(state.session, entity_id), state}

  def handle_call({:travel, destination_id}, _from, state) do
    case GameSession.travel(state.session, destination_id) do
      {:ok, _travel_result} = success ->
        player_id = GameSession.player(state.session)

        case LivingBriarRuntime.set_player_location(state.runtime, player_id, destination_id) do
          {:ok, _presence} -> {:reply, success, state}
          {:error, reason} -> {:reply, {:error, {:regional_presence_sync_failed, reason}}, state}
        end

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call(:player, _from, state), do:
    {:reply, GameSession.player(state.session), state}

  def handle_call(:player_location, _from, state), do:
    {:reply, GameSession.player_location(state.session), state}

  def handle_call(:local_entities, _from, state), do:
    {:reply, GameSession.local_entities(state.session), state}

  @impl true
  def terminate(_reason, state) do
    stop_runtime(state.runtime)
    cleanup_inner_session(state.session)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_snapshot(nil), do: nil
  defp safe_snapshot(runtime) do
    LivingBriarRuntime.snapshot(runtime)
  catch
    :exit, _ -> nil
  end

  defp cleanup_inner_session(nil), do: :ok
  defp cleanup_inner_session(session) do
    if Process.alive?(session) do
      GameSession.cleanup(session)
      stop_inner_session(session)
    end
    :ok
  catch
    :exit, _ -> :ok
  end

  defp stop_runtime(nil), do: :ok
  defp stop_runtime(runtime) do
    if Process.alive?(runtime), do: LivingBriarRuntime.stop(runtime)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp stop_inner_session(nil), do: :ok
  defp stop_inner_session(session) do
    if Process.alive?(session), do: GenServer.stop(session, :normal)
    :ok
  catch
    :exit, _ -> :ok
  end
end
