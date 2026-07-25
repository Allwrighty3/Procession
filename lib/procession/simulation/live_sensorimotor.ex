defmodule Procession.Simulation.LiveSensorimotor do
  use GenServer

  @moduledoc """
  Live OTP owner for one entity's developmental sensorimotor loop.

  The process monitors its entity incarnation. If the entity crashes and is
  restarted by OTP, the loop preserves its relational geometry and reattaches to
  the replacement process. Cycles are rejected while no entity incarnation is
  attached, and the loop terminates if the entity does not return.
  """

  alias Procession.Simulation.DevelopmentalSensorimotorLoop

  @reattach_attempts 50
  @reattach_delay_ms 10

  def child_spec(opts) do
    entity_id = Keyword.fetch!(opts, :entity_id)

    %{
      id: {__MODULE__, entity_id},
      start: {__MODULE__, :start_link, [opts]},
      restart: :transient,
      shutdown: 5_000,
      type: :worker
    }
  end

  def start_link(opts) do
    entity_id = Keyword.fetch!(opts, :entity_id)
    name = Keyword.get(opts, :name, via_tuple(entity_id))
    GenServer.start_link(__MODULE__, {entity_id, opts}, name: name)
  end

  def cycle(server_or_entity_id, features, tick, feedback_fun, opts \\ []) do
    GenServer.call(server_ref(server_or_entity_id), {:cycle, features, tick, feedback_fun, opts})
  end

  def trace(server_or_entity_id) do
    GenServer.call(server_ref(server_or_entity_id), :trace)
  end

  def entity_id(server_or_entity_id) do
    GenServer.call(server_ref(server_or_entity_id), :entity_id)
  end

  def via_tuple(entity_id) do
    {:via, Registry, {Procession.EntityRegistry, {:sensorimotor, entity_id}}}
  end

  @impl true
  def init({entity_id, opts}) do
    loop_opts = Keyword.get(opts, :loop_opts, [])
    owner_pid = Keyword.fetch!(opts, :owner_pid)
    owner_monitor = Process.monitor(owner_pid)

    {:ok,
     %{
       entity_id: entity_id,
       owner_pid: owner_pid,
       owner_monitor: owner_monitor,
       reattach_attempts: @reattach_attempts,
       loop: DevelopmentalSensorimotorLoop.new(loop_opts)
     }}
  end

  @impl true
  def handle_call(:entity_id, _from, state) do
    {:reply, state.entity_id, state}
  end

  @impl true
  def handle_call(:trace, _from, state) do
    trace =
      state.loop
      |> DevelopmentalSensorimotorLoop.trace()
      |> Map.put(:entity_id, state.entity_id)
      |> Map.put(:attached?, is_pid(state.owner_pid))

    {:reply, trace, state}
  end

  @impl true
  def handle_call({:cycle, _features, _tick, _feedback_fun, _opts}, _from, %{owner_pid: nil} = state) do
    {:reply, {:error, :entity_restarting}, state}
  end

  def handle_call({:cycle, features, tick, feedback_fun, opts}, _from, state) do
    {loop, outcome} =
      DevelopmentalSensorimotorLoop.cycle(
        state.loop,
        features,
        tick,
        feedback_fun,
        opts
      )

    result = %{
      entity_id: state.entity_id,
      outcome: outcome,
      trace: DevelopmentalSensorimotorLoop.trace(loop)
    }

    {:reply, {:ok, result}, %{state | loop: loop}}
  end

  @impl true
  def handle_info({:DOWN, reference, :process, pid, _reason}, %{owner_monitor: reference, owner_pid: pid} = state) do
    Process.send_after(self(), :reattach_owner, 0)

    {:noreply,
     %{state | owner_pid: nil, owner_monitor: nil, reattach_attempts: @reattach_attempts}}
  end

  def handle_info(:reattach_owner, state) do
    case Registry.lookup(Procession.EntityRegistry, state.entity_id) do
      [{pid, _value}] ->
        {:noreply,
         %{
           state
           | owner_pid: pid,
             owner_monitor: Process.monitor(pid),
             reattach_attempts: @reattach_attempts
         }}

      [] when state.reattach_attempts > 0 ->
        Process.send_after(self(), :reattach_owner, @reattach_delay_ms)
        {:noreply, %{state | reattach_attempts: state.reattach_attempts - 1}}

      [] ->
        {:stop, :normal, state}
    end
  end

  defp server_ref(server) when is_pid(server), do: server
  defp server_ref({:via, _module, _term} = server), do: server
  defp server_ref(entity_id), do: via_tuple(entity_id)
end
