defmodule Procession.Simulation.LiveSensorimotor do
  use GenServer

  @moduledoc """
  Live OTP owner for one entity's developmental sensorimotor loop.

  This process keeps relational sensory geometry and motor-body adaptation local to
  the entity identified at startup. Callers provide only sensed features, elapsed
  cycle identity, and a world feedback function grounded in the emitted bodily
  consequence.
  """

  alias Procession.Simulation.DevelopmentalSensorimotorLoop

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
    {:ok, %{entity_id: entity_id, loop: DevelopmentalSensorimotorLoop.new(loop_opts)}}
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

    {:reply, trace, state}
  end

  @impl true
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

  defp server_ref(server) when is_pid(server), do: server
  defp server_ref({:via, _module, _term} = server), do: server
  defp server_ref(entity_id), do: via_tuple(entity_id)
end