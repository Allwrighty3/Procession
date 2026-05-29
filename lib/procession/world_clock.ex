defmodule Procession.WorldClock do
  use GenServer

  @moduledoc """

  Manually controlled world simulation clock.

  The clock coordinates world ticks by delegating to `Procession.Game.tick_world/0`.
  It does not own entity behavior, execute behavior metadata directly, or replace
  manual calls to `Procession.Game.tick_world/0`
  """

  defstruct tick_count: 0,
            last_tick: nil

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def tick(clock) do
    GenServer.call(clock, :tick)
  end

  def last_tick(clock) do
    GenServer.call(clock, :last_tick)
  end

  def tick_count(clock) do
    GenServer.call(clock, :tick_count)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    case Procession.Game.tick_world() do
      {:ok, summary} ->
        tick_summary =
          summary
          |> Map.put(:clock_tick, state.tick_count + 1)

        updated_state = %{
          state
          | tick_count: state.tick_count + 1,
            last_tick: tick_summary
        }

        {:reply, {:ok, tick_summary}, updated_state}

      {:error, reason} = error ->
        tick_summary = %{
          status: :error,
          reason: reason,
          clock_tick: state.tick_count + 1
        }

        updated_state = %{
          state
          | tick_count: state.tick_count + 1,
            last_tick: tick_summary
        }

        {:reply, error, updated_state}
    end
  end

  @impl true
  def handle_call(:last_tick, _from, state) do
    {:reply, state.last_tick, state}
  end

  @impl true
  def handle_call(:tick_count, _from, state) do
    {:reply, state.tick_count, state}
  end
end
