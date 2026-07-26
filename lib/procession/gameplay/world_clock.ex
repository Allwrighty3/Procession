defmodule Procession.WorldClock do
  use GenServer

  @name __MODULE__

  @moduledoc """
  Manually controlled world simulation clock.

  The clock coordinates an optional authoritative causal world, the existing
  live-entity tick path, optional coarse travel with grounded route evidence,
  bounded dormant locomotion decisions on an explicit cadence, optional grounded
  region-observation publication, and optional post-tick region-resolution
  reconciliation. It schedules time only; it does not decide perception, motor
  output, physical consequences, entity behavior, travel intent, route conditions,
  or causal relevance.
  """

  defstruct tick_count: 0,
            last_tick: nil,
            interval_ms: nil,
            timer_ref: nil,
            coarse_travel: false,
            coarse_travel_server: Procession.Simulation.CoarseTravel,
            route_evidence: false,
            route_evidence_server: Procession.Simulation.RouteEvidence,
            dormant_locomotion: false,
            dormant_locomotion_module: Procession.Simulation.DormantLocomotionBatch,
            dormant_locomotion_cadence: 1,
            dormant_locomotion_opts: [],
            dormant_exit_provider: nil,
            resolution_policy: false,
            resolution_policy_opts: [],
            region_observations: false,
            region_observation_opts: []

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
  def init(opts) do
    {:ok,
     %__MODULE__{
       coarse_travel: Keyword.get(opts, :coarse_travel, false),
       coarse_travel_server:
         Keyword.get(opts, :coarse_travel_server, Procession.Simulation.CoarseTravel),
       route_evidence: Keyword.get(opts, :route_evidence, false),
       route_evidence_server:
         Keyword.get(opts, :route_evidence_server, Procession.Simulation.RouteEvidence),
       dormant_locomotion: Keyword.get(opts, :dormant_locomotion, false),
       dormant_locomotion_module:
         Keyword.get(opts, :dormant_locomotion_module, Procession.Simulation.DormantLocomotionBatch),
       dormant_locomotion_cadence:
         normalize_cadence(Keyword.get(opts, :dormant_locomotion_cadence, 1)),
       dormant_locomotion_opts: Keyword.get(opts, :dormant_locomotion_opts, []),
       dormant_exit_provider: Keyword.get(opts, :dormant_exit_provider),
       resolution_policy: Keyword.get(opts, :resolution_policy, false),
       resolution_policy_opts: Keyword.get(opts, :resolution_policy_opts, []),
       region_observations: Keyword.get(opts, :region_observations, false),
       region_observation_opts: Keyword.get(opts, :region_observation_opts, [])
     }}
  end

  defp run_tick(state) do
    next_tick = state.tick_count + 1
    causal_world = Procession.Simulation.LiveCausalWorld.tick_if_running()

    entity_summary =
      case Procession.Game.tick_all_live_entities() do
        {:ok, summary} -> summary
        {:error, reason} -> %{status: :error, reason: reason}
      end

    coarse_travel = advance_coarse_travel(state, next_tick)
    dormant_locomotion = run_dormant_locomotion(state, next_tick)
    observations = refresh_region_observations(state, next_tick)
    resolution_policy = reconcile_resolutions(state, next_tick)

    tick_summary =
      entity_summary
      |> Map.put(:causal_world, normalize_causal_world(causal_world))
      |> Map.put(:coarse_travel, coarse_travel)
      |> Map.put(:dormant_locomotion, dormant_locomotion)
      |> Map.put(:region_observations, observations)
      |> Map.put(:resolution_policy, resolution_policy)
      |> Map.put(:clock_tick, next_tick)

    %{
      state
      | tick_count: next_tick,
        last_tick: tick_summary
    }
  end

  defp advance_coarse_travel(%{coarse_travel: false}, _tick), do: :disabled

  defp advance_coarse_travel(%{route_evidence: true} = state, tick) do
    safe_call(fn ->
      Procession.Simulation.RouteEvidence.advance_travel(
        tick,
        state.coarse_travel_server,
        state.route_evidence_server
      )
    end)
  end

  defp advance_coarse_travel(state, _tick) do
    safe_call(fn -> Procession.Simulation.CoarseTravel.advance(1, state.coarse_travel_server) end)
  end

  defp run_dormant_locomotion(%{dormant_locomotion: false}, _tick), do: :disabled

  defp run_dormant_locomotion(state, tick) do
    cadence = state.dormant_locomotion_cadence

    if rem(tick, cadence) == 0 do
      case state.dormant_exit_provider do
        provider when is_function(provider, 2) ->
          opts =
            state.dormant_locomotion_opts
            |> Keyword.put_new(:travel_server, state.coarse_travel_server)

          safe_call(fn -> state.dormant_locomotion_module.run(tick, provider, opts) end)

        _ ->
          %{status: :error, reason: :dormant_exit_provider_required}
      end
    else
      %{
        status: :deferred,
        cadence: cadence,
        next_eligible_tick: tick + (cadence - rem(tick, cadence))
      }
    end
  end

  defp refresh_region_observations(%{region_observations: false}, _tick), do: :disabled

  defp refresh_region_observations(state, tick) do
    safe_call(fn ->
      Procession.Simulation.RegionObservationPublisher.refresh(
        tick,
        state.region_observation_opts
      )
    end)
  end

  defp reconcile_resolutions(%{resolution_policy: false}, _tick), do: :disabled

  defp reconcile_resolutions(state, tick) do
    safe_call(fn ->
      Procession.Simulation.AutomaticResolutionPolicy.reconcile(
        tick,
        state.resolution_policy_opts
      )
    end)
  end

  defp safe_call(fun) do
    try do
      fun.()
    rescue
      error -> %{status: :error, reason: Exception.message(error)}
    catch
      :exit, reason -> %{status: :error, reason: reason}
    end
  end

  defp normalize_cadence(value) when is_integer(value) and value > 0, do: value
  defp normalize_cadence(_value), do: 1

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
