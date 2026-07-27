defmodule Procession.LivingGameSession do
  @moduledoc """
  Session-compatible owner that joins the starter-area gameplay shell to one stateful
  `Procession.Simulation.LivingBriarRuntime`.

  It accepts the same GenServer calls used by `Procession.GameSession`, delegates ordinary
  gameplay to an inner session, and advances Living Briar exactly once for every session tick.
  """

  use GenServer

  alias Procession.GameSession
  alias Procession.Simulation.LivingBriarRuntime

  defstruct [:session, :runtime, :startup]

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)
  def start(opts \\ []), do: GenServer.start(__MODULE__, opts)

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

    with {:ok, startup} <- GameSession.start_demo(prompt),
         {:ok, runtime} <- LivingBriarRuntime.start_link(runtime_opts) do
      {:ok, %__MODULE__{session: startup.session, runtime: runtime, startup: startup}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:startup, _from, state), do: {:reply, state.startup, state}

  def handle_call(:tick, _from, state) do
    with {:ok, tick_summary} <- GameSession.tick(state.session),
         {:ok, observation} <- LivingBriarRuntime.step(state.runtime) do
      combined = Map.put(tick_summary, :living_briar, observation)
      {:reply, {:ok, combined}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
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

  def handle_call({:travel, destination_id}, _from, state), do:
    {:reply, GameSession.travel(state.session, destination_id), state}

  def handle_call(:player, _from, state), do:
    {:reply, GameSession.player(state.session), state}

  def handle_call(:player_location, _from, state), do:
    {:reply, GameSession.player_location(state.session), state}

  def handle_call(:local_entities, _from, state), do:
    {:reply, GameSession.local_entities(state.session), state}

  @impl true
  def terminate(_reason, state) do
    stop_runtime(state.runtime)

    if is_pid(state.session) and Process.alive?(state.session) do
      GameSession.cleanup(state.session)
      stop_inner_session(state.session)
    end

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
