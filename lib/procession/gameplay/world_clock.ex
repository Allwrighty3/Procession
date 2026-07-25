defmodule Procession.WorldClock do
  use GenServer

  @name __MODULE__

  @moduledoc """
  Manually controlled world simulation clock.

  The clock coordinates an optional authoritative causal world and the existing
  live-entity tick path. It schedules time only; it does not decide perception,
  motor output, physical consequences, or entity behavior.
  """

  defstruct tick_count: 0,
            last_tick: nil,
            interval_ms: nil,
            timer_ref: nil

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def tick(clock \\ @name), do: GenServer.call(clock, :tick)
  def last_tick(clock \\ @name), do: GenServer.call(clock, :last_tick)
  def tick_count(clock \\ @name), do: GenServer.call(clock, :tick_count)

  def start_interval(clock \\ @name, interval_ms)
      when is_integer(interval_ms) and interval_ms > 0 do
    GenServer.call(clock, {:start_interval, interval_ms})
  end

  def stop_interval(clock \\ @name), do: GenServer.call(clock, :stop_interval)
  def interval_running?(clock \\ @name), do: GenServer.call(clock, :interval_running?)

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  defp run_tick(state) do
    causal_world = Procession.Simulation.LiveCausalWorld.tick_if_running()

    entity_summary =
      case Procession.Game.tick_all_live_entities() do
        {:ok, summary} -> summary
        {:error, reason} -> %{status: :error, reason: reason}
      end

    tick_summary =
      entity_summary
      |> Map.put(:causal_world, normalize_causal_world(causal_world))
      |> Map.put(:clock_tick, state.tick_count + 1)

    %{
      state
      | tick_count: state.tick_count + 1,
        last_tick: tick_summary
    }
  end

  defp normalize_causal_world({:ok, summary}), do: summary
  defp normalize_causal_world({:error, reason}), do: %{status: :error, reason: reason}

  defp schedule_next_interval(%{interval_ms: nil} = state), do: state

  defp schedule_next_interval(state) do
    %{state | timer_ref: Process.send_after(self(), :interval_tick, state.interval_ms)}
  end

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: timer_ref} = state) do
    Process.cancel_timer(timer_ref)
    %{state | timer_ref: nil, interval_ms: nil}
  end

  @impl true
  def handle_info(:interval_tick, state) do
    updated_state =
      state
      |> run_tick()
      |> schedule_next_interval()

    {:noreply, updated_state}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    updated_state = run_tick(state)
    {:reply, {:ok, updated_state.last_tick}, updated_state}
  end

  def handle_call(:last_tick, _from, state), do: {:reply, state.last_tick, state}
  def handle_call(:tick_count, _from, state), do: {:reply, state.tick_count, state}

  def handle_call({:start_interval, interval_ms}, _from, state) do
    state = cancel_timer(state)

    updated_state = %{
      state
      | interval_ms: interval_ms,
        timer_ref: Process.send_after(self(), :interval_tick, interval_ms)
    }

    {:reply, :ok, updated_state}
  end

  def handle_call(:stop_interval, _from, state) do
    updated_state = cancel_timer(state)
    {:reply, :ok, updated_state}
  end

  def handle_call(:interval_running?, _from, state) do
    {:reply, not is_nil(state.timer_ref), state}
  end
end
