defmodule Procession.WorldClock do
  use GenServer

  alias Procession.TemporalProcess

  @name __MODULE__

  @moduledoc """
  Authoritative, manually controlled world simulation clock.

  World time is monotonic and independent from wall-clock time. Existing world ticks
  remain available, but each tick now advances simulation time by a configured amount.
  Temporal processes are inert validated data ordered by their next transition time.
  """

  defstruct tick_count: 0,
            last_tick: nil,
            interval_ms: nil,
            timer_ref: nil,
            now_ms: 0,
            tick_duration_ms: 1_000,
            processes: %{},
            completed_processes: []

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def tick(clock \\ @name), do: GenServer.call(clock, :tick)
  def last_tick(clock \\ @name), do: GenServer.call(clock, :last_tick)
  def tick_count(clock \\ @name), do: GenServer.call(clock, :tick_count)
  def now(clock \\ @name), do: GenServer.call(clock, :now)
  def active_processes(clock \\ @name), do: GenServer.call(clock, :active_processes)
  def completed_processes(clock \\ @name), do: GenServer.call(clock, :completed_processes)

  def start_process(clock \\ @name, attrs) when is_map(attrs) do
    GenServer.call(clock, {:start_process, attrs})
  end

  def cancel_process(clock \\ @name, process_id) do
    GenServer.call(clock, {:cancel_process, process_id})
  end

  def advance_to(clock \\ @name, target_ms)
      when is_integer(target_ms) and target_ms >= 0 do
    GenServer.call(clock, {:advance_to, target_ms})
  end

  def advance_to_next(clock \\ @name), do: GenServer.call(clock, :advance_to_next)

  def start_interval(clock \\ @name, interval_ms)
      when is_integer(interval_ms) and interval_ms > 0 do
    GenServer.call(clock, {:start_interval, interval_ms})
  end

  def stop_interval(clock \\ @name), do: GenServer.call(clock, :stop_interval)
  def interval_running?(clock \\ @name), do: GenServer.call(clock, :interval_running?)

  @impl true
  def init(opts) do
    {:ok,
     %__MODULE__{
       now_ms: Keyword.get(opts, :initial_time_ms, 0),
       tick_duration_ms: Keyword.get(opts, :tick_duration_ms, 1_000)
     }}
  end

  defp run_tick(state) do
    advanced_state = advance_state_to(state, state.now_ms + state.tick_duration_ms)

    case Procession.Game.tick_all_live_entities() do
      {:ok, summary} ->
        tick_summary =
          summary
          |> Map.put(:clock_tick, state.tick_count + 1)
          |> Map.put(:world_time_ms, advanced_state.now_ms)
          |> Map.put(:completed_processes, newly_completed(state, advanced_state))

        %{advanced_state | tick_count: state.tick_count + 1, last_tick: tick_summary}

      {:error, reason} ->
        tick_summary = %{
          status: :error,
          reason: reason,
          clock_tick: state.tick_count + 1,
          world_time_ms: advanced_state.now_ms,
          completed_processes: newly_completed(state, advanced_state)
        }

        %{advanced_state | tick_count: state.tick_count + 1, last_tick: tick_summary}
    end
  end

  defp newly_completed(before, after_state) do
    count = length(after_state.completed_processes) - length(before.completed_processes)
    Enum.take(after_state.completed_processes, max(count, 0))
  end

  defp advance_state_to(state, target_ms) do
    {due, pending} =
      state.processes
      |> Map.values()
      |> Enum.split_with(&TemporalProcess.due?(&1, target_ms))

    completed =
      due
      |> Enum.sort_by(&{&1.next_transition_at, inspect(&1.id)})
      |> Enum.map(&TemporalProcess.complete(&1, &1.next_transition_at))

    %{
      state
      | now_ms: target_ms,
        processes: Map.new(pending, &{&1.id, &1}),
        completed_processes: Enum.reverse(completed) ++ state.completed_processes
    }
  end

  defp next_transition_time(state) do
    state.processes
    |> Map.values()
    |> Enum.map(& &1.next_transition_at)
    |> Enum.min(fn -> nil end)
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
    updated_state = state |> run_tick() |> schedule_next_interval()
    {:noreply, updated_state}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    updated_state = run_tick(state)
    {:reply, {:ok, updated_state.last_tick}, updated_state}
  end

  def handle_call(:last_tick, _from, state), do: {:reply, state.last_tick, state}
  def handle_call(:tick_count, _from, state), do: {:reply, state.tick_count, state}
  def handle_call(:now, _from, state), do: {:reply, state.now_ms, state}

  def handle_call(:active_processes, _from, state) do
    processes = state.processes |> Map.values() |> Enum.sort_by(&{&1.next_transition_at, inspect(&1.id)})
    {:reply, processes, state}
  end

  def handle_call(:completed_processes, _from, state) do
    {:reply, state.completed_processes, state}
  end

  def handle_call({:start_process, attrs}, _from, state) do
    attrs =
      attrs
      |> Map.put_new(:started_at, state.now_ms)
      |> Map.put_new_lazy(:next_transition_at, fn ->
        state.now_ms + Map.get(attrs, :duration_ms, 0)
      end)
      |> Map.delete(:duration_ms)

    case TemporalProcess.new(attrs) do
      {:ok, process} ->
        if Map.has_key?(state.processes, process.id) do
          {:reply, {:error, :temporal_process_already_exists}, state}
        else
          updated_state = %{state | processes: Map.put(state.processes, process.id, process)}
          {:reply, {:ok, process}, updated_state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:cancel_process, process_id}, _from, state) do
    case Map.pop(state.processes, process_id) do
      {nil, _processes} ->
        {:reply, {:error, :temporal_process_not_found}, state}

      {process, processes} ->
        cancelled = %{process | state: :cancelled}
        {:reply, {:ok, cancelled}, %{state | processes: processes}}
    end
  end

  def handle_call({:advance_to, target_ms}, _from, state) when target_ms < state.now_ms do
    {:reply, {:error, :world_time_cannot_move_backward}, state}
  end

  def handle_call({:advance_to, target_ms}, _from, state) do
    updated_state = advance_state_to(state, target_ms)
    {:reply, {:ok, newly_completed(state, updated_state)}, updated_state}
  end

  def handle_call(:advance_to_next, _from, state) do
    case next_transition_time(state) do
      nil ->
        {:reply, {:ok, []}, state}

      next_time ->
        updated_state = advance_state_to(state, next_time)
        {:reply, {:ok, newly_completed(state, updated_state)}, updated_state}
    end
  end

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
