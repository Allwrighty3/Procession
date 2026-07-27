defmodule Procession.LivingGameSession do
  @moduledoc """
  Session-compatible owner joining the starter gameplay shell to one stateful Living Briar world.

  The session also owns any ongoing player physical process. Material kernels continue to expose
  instantaneous primitive consequences, while this owner decides when those consequences receive
  another opportunity as world time advances.
  """

  use GenServer

  alias Procession.GameSession
  alias Procession.Simulation.TransitAwareLivingBriarRuntime, as: LivingBriarRuntime

  @persistent_primitives [:contact_loose_raw, :manipulate_held_raw]
  @epsilon 1.0e-9

  defstruct [:session, :runtime, :startup, :player_action]

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)
  def start(opts \\ []), do: GenServer.start(__MODULE__, opts)

  def physical_action(session, primitive, opts \\ []),
    do: GenServer.call(session, {:player_physical_action, primitive, opts})

  def begin_physical_action(session, primitive) when primitive in @persistent_primitives,
    do: GenServer.call(session, {:begin_player_action, primitive})

  def begin_physical_action(_session, _primitive), do: {:error, :invalid_player_primitive}

  def interrupt_physical_action(session), do: GenServer.call(session, :interrupt_player_action)
  def physical_action_status(session), do: GenServer.call(session, :player_action_status)

  def start_demo(prompt \\ "a quiet frontier town", opts \\ []) do
    with {:ok, session} <- start(Keyword.put(opts, :prompt, prompt)),
         startup <- GenServer.call(session, :startup) do
      {:ok, Map.put(startup, :session, session)}
    end
  end

  @impl true
  def init(opts) do
    prompt = Keyword.get(opts, :prompt, "a quiet frontier town")
    runtime_opts = Keyword.take(opts, [:seed, :budget, :cadence, :transit_budget, :transit_cadence])

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
      {progress, next_state} = advance_player_action(state)

      living_observation =
        observation
        |> Map.put(:player_action, next_state.player_action)
        |> Map.put(:player_action_progress, progress)

      {:reply, {:ok, Map.put(tick_summary, :living_briar, living_observation)}, next_state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:begin_player_action, primitive}, _from, %{player_action: nil} = state)
      when primitive in @persistent_primitives do
    action = %{primitive: primitive, started_at_tick: current_tick(state), accumulated: 0.0}
    result = %{kind: :physical_process_started, primitive: primitive, accumulated: 0.0}
    {:reply, {:ok, result}, %{state | player_action: action}}
  end

  def handle_call({:begin_player_action, primitive}, _from, state)
      when primitive in @persistent_primitives do
    {:reply, {:error, :player_action_in_progress}, state}
  end

  def handle_call({:begin_player_action, _primitive}, _from, state),
    do: {:reply, {:error, :invalid_player_primitive}, state}

  def handle_call(:interrupt_player_action, _from, %{player_action: nil} = state),
    do: {:reply, {:error, :no_player_action_in_progress}, state}

  def handle_call(:interrupt_player_action, _from, state) do
    result = %{kind: :physical_process_interrupted, action: state.player_action}
    {:reply, {:ok, result}, %{state | player_action: nil}}
  end

  def handle_call(:player_action_status, _from, state),
    do: {:reply, {:ok, state.player_action}, state}

  def handle_call({:player_physical_action, _primitive, _opts}, _from,
        %{player_action: action} = state)
      when not is_nil(action) do
    {:reply, {:error, :player_action_in_progress}, state}
  end

  def handle_call({:player_physical_action, primitive, opts}, _from, state) do
    {:reply, LivingBriarRuntime.player_action(state.runtime, primitive, opts), state}
  end

  def handle_call(:summary, _from, state) do
    summary = GameSession.summary(state.session)

    living =
      state.runtime
      |> LivingBriarRuntime.snapshot()
      |> Map.put(:player_action, state.player_action)

    {:reply, Map.put(summary, :living_briar, living), state}
  end

  def handle_call(:active_entities, _from, state), do:
    {:reply, GameSession.active_entities(state.session), state}

  def handle_call({:owns_entity?, entity_id}, _from, state), do:
    {:reply, GameSession.owns_entity?(state.session, entity_id), state}

  def handle_call(:cleanup, _from, state) do
    living_summary = safe_snapshot(state.runtime, state.player_action)
    stop_runtime(state.runtime)
    cleanup = GameSession.cleanup(state.session)
    stop_inner_session(state.session)

    {:reply, Map.put(cleanup, :living_briar, living_summary),
     %{state | runtime: nil, session: nil, player_action: nil}}
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
          {:ok, _presence} -> {:reply, success, %{state | player_action: nil}}
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

  defp advance_player_action(%{player_action: nil} = state), do: {nil, state}

  defp advance_player_action(state) do
    action = state.player_action

    case LivingBriarRuntime.player_action(state.runtime, action.primitive, []) do
      {:ok, consequence} ->
        accumulated = action.accumulated + Map.get(consequence, :amount, 0.0)
        updated = %{action | accumulated: accumulated}
        snapshot = LivingBriarRuntime.snapshot(state.runtime)

        if physically_continuable?(updated, consequence, snapshot) do
          {%{status: :continuing, consequence: consequence, action: updated},
           %{state | player_action: updated}}
        else
          {%{status: :ended, consequence: consequence, action: updated},
           %{state | player_action: nil}}
        end

      {:error, reason} ->
        {%{status: :interrupted, reason: reason, action: action}, %{state | player_action: nil}}
    end
  end

  defp physically_continuable?(%{primitive: :contact_loose_raw}, consequence, snapshot) do
    body = snapshot.player_body
    amount = Map.get(consequence, :amount, 0.0)
    room = max(0.0, body.capacity - body.raw - body.usable)
    amount > @epsilon and room > @epsilon and amount + @epsilon >= body.gather_rate
  end

  defp physically_continuable?(%{primitive: :manipulate_held_raw}, consequence, snapshot) do
    Map.get(consequence, :amount, 0.0) > @epsilon and snapshot.player_body.raw > @epsilon
  end

  defp current_tick(state) do
    state.runtime
    |> LivingBriarRuntime.snapshot()
    |> Map.get(:tick, 0)
  end

  defp safe_snapshot(nil, _player_action), do: nil

  defp safe_snapshot(runtime, player_action) do
    runtime
    |> LivingBriarRuntime.snapshot()
    |> Map.put(:player_action, player_action)
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
