defmodule Procession.Simulation.LiveCausalWorldTest do
  use ExUnit.Case, async: false

  alias Procession.EntitySupervisor
  alias Procession.Simulation.LiveCausalWorld
  alias Procession.Simulation.LiveSensorimotor

  setup do
    if pid = Process.whereis(LiveCausalWorld) do
      GenServer.stop(pid)
    end

    ids = ["causal_mara", "causal_clock", "causal_missing_sensor"]

    Enum.each(ids, fn id ->
      if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
    end)

    on_exit(fn ->
      if pid = Process.whereis(LiveCausalWorld) do
        GenServer.stop(pid)
      end

      Enum.each(ids, fn id ->
        if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
      end)
    end)

    :ok
  end

  test "live world persists physical state while the entity process owns mental state" do
    start_entity("causal_mara", :live_world_test, {1, 1})

    world =
      start_supervised!({LiveCausalWorld,
        kernel_opts: [
          bounds: {1, 1},
          obstacles: [{0, 1}, {1, 0}],
          entities: [%{id: "causal_mara", position: {1, 1}}],
          resources: [%{id: "food", position: {1, 1}, quantity: 0.4}]
        ]})

    physical = LiveCausalWorld.state(world)
    refute Map.has_key?(physical.entities["causal_mara"], :loop)

    assert {:ok, first} = LiveCausalWorld.tick(world)
    assert first.tick == 1
    assert first.entities["causal_mara"].sensorimotor.cycles == 1

    assert {:ok, second} = LiveCausalWorld.tick(world)
    assert second.tick == 2
    assert second.entities["causal_mara"].sensorimotor.cycles == 2
    assert second.resources["food"] < first.resources["food"]
  end

  test "stopping the world does not stop or erase an entity mind" do
    start_entity("causal_mara", :world_lifetime_test, {0, 0})

    world =
      start_supervised!({LiveCausalWorld,
        name: :temporary_causal_world,
        kernel_opts: [entities: [%{id: "causal_mara", position: {0, 0}}]]})

    assert {:ok, trace} = LiveCausalWorld.tick(world)
    assert trace.entities["causal_mara"].sensorimotor.cycles == 1

    GenServer.stop(world)

    assert Process.alive?(sensorimotor_pid("causal_mara"))
    assert LiveSensorimotor.trace("causal_mara").cycles == 1
  end

  test "world rejects a physical participant without a sensorimotor owner" do
    assert {:ok, _pid} = EntitySupervisor.start_npc("causal_missing_sensor", %{})

    world =
      start_supervised!({LiveCausalWorld,
        name: :missing_sensor_world,
        kernel_opts: [entities: [%{id: "causal_missing_sensor", position: {0, 0}}]]})

    assert {:error, {"causal_missing_sensor", :sensorimotor_not_enabled}} =
             LiveCausalWorld.tick(world)

    assert LiveCausalWorld.state(world).tick == 1
  end

  test "world clock advances a running causal world without named entity actions" do
    start_entity("causal_clock", :clock_world_test, {0, 0})

    start_supervised!({LiveCausalWorld,
      kernel_opts: [entities: [%{id: "causal_clock", position: {0, 0}}]]})

    clock = start_supervised!({Procession.WorldClock, name: :causal_world_test_clock})

    assert {:ok, summary} = Procession.WorldClock.tick(clock)
    assert summary.clock_tick == 1
    assert summary.causal_world.tick == 1
    assert summary.causal_world.entities["causal_clock"].sensorimotor.cycles == 1
  end

  test "world clock reports a clean skip when no causal world is active" do
    clock = start_supervised!({Procession.WorldClock, name: :empty_causal_world_test_clock})

    assert {:ok, summary} = Procession.WorldClock.tick(clock)
    assert summary.causal_world == %{status: :skipped, reason: :causal_world_not_running}
  end

  defp start_entity(id, salt, position) do
    assert {:ok, _pid} =
             EntitySupervisor.start_npc(id, %{
               sensorimotor: [
                 position: position,
                 field_opts: [micro_nodes: 64, input_width: 3, encoding_salt: salt],
                 body_opts: [initial_coordination: 1.0]
               ]
             })
  end

  defp sensorimotor_pid(id) do
    [{pid, _value}] = Registry.lookup(Procession.EntityRegistry, {:sensorimotor, id})
    pid
  end
end
