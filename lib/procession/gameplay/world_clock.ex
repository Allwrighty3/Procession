defmodule Procession.WorldClock do
  use GenServer

  @name __MODULE__

  @moduledoc """

  Manually controlled world simulation clock.

  The clock coordinates world ticks by delegating to `Procession.Game.tick_world/0`.
  It does not own entity behavior, execute behavior metadata directly, or replace
  manual calls to `Procession.Game.tick_world/0`
  """

  defstruct tick_count: 0,
            last_tick: nil,
            interval_ms: nil,
            timer_ref: nil

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def tick(clock \\ @name) do
    GenServer.call(clock, :tick)
  end

  def last_tick(clock \\ @name) do
    GenServer.call(clock, :last_tick)
  end

  def tick_count(clock \\ @name) do
    GenServer.call(clock, :tick_count)
  end

  def start_interval(clock \\ @name, interval_ms)
      when is_integer(interval_ms) and interval_ms > 0 do
    GenServer.call(clock, {:start_interval, interval_ms})
  end

  def stop_interval(clock \\ @name) do
    GenServer.call(clock, :stop_interval)
  end

  def interval_running?(clock \\ @name) do
    GenServer.call(clock, :interval_running?)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  defp run_tick(state) do
    case Procession.Game.tick_world() do
      {:ok, summary} ->
        tick_summary =
          summary
          |> Map.put(:clock_tick, state.tick_count + 1)

        %{
          state
          | tick_count: state.tick_count + 1,
            last_tick: tick_summary
        }

      {:error, reason} ->
        tick_summary = %{
          status: :error,
          reason: reason,
          clock_tick: state.tick_count + 1
        }

        %{
          state
          | tick_count: state.tick_count + 1,
            last_tick: tick_summary
        }
    end
  end

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

  @impl true
  def handle_call(:last_tick, _from, state) do
    {:reply, state.last_tick, state}
  end

  @impl true
  def handle_call(:tick_count, _from, state) do
    {:reply, state.tick_count, state}
  end

  @impl true
  def handle_call({:start_interval, interval_ms}, _from, state) do
    state = cancel_timer(state)

    updated_state = %{
      state
      | interval_ms: interval_ms,
        timer_ref: Process.send_after(self(), :interval_tick, interval_ms)
    }

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:stop_interval, _from, state) do
    updated_state = cancel_timer(state)

    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:interval_running?, _from, state) do
    {:reply, not is_nil(state.timer_ref), state}
  end
end
