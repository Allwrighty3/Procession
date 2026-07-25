defmodule Procession.EntitySensorimotorIntegrationTest do
  use ExUnit.Case, async: false

  alias Procession.EntitySupervisor
  alias Procession.Simulation.LiveSensorimotor

  setup do
    id = "sensorimotor_entity_#{System.unique_integer([:positive])}"
    on_exit(fn -> EntitySupervisor.stop_entity(id) end)
    %{id: id}
  end

  test "ordinary entities remain sensorimotor-free", %{id: id} do
    assert {:ok, _pid} = EntitySupervisor.start_npc(id, %{name: "Ordinary"})
    refute EntitySupervisor.sensorimotor_enabled?(id)
    assert {:error, :sensorimotor_not_enabled} = EntitySupervisor.sensorimotor_trace(id)
  end

  test "opted-in entities own persistent sensorimotor state", %{id: id} do
    field_opts = [
      micro_nodes: 64,
      input_width: 3,
      encoding_salt: {:entity_loop, id},
      output_source_threshold: 0.0
    ]

    assert {:ok, _pid} =
             EntitySupervisor.start_npc(id, %{
               name: "Embodied",
               sensorimotor: [
                 field_opts: field_opts,
                 body_opts: [initial_coordination: 1.0],
                 position: {1, 1}
               ]
             })

    assert EntitySupervisor.sensorimotor_enabled?(id)

    feedback = fn outcome, position ->
      {
        [
          {:proprioceptive_channel, :motor_consequence, outcome.consequence},
          {:spatial_channel, :position, position}
        ],
        if(outcome.displaced?, do: 1.0, else: -0.2)
      }
    end

    opts = [
      seed: 7,
      bounds: {3, 3},
      output_exploration: 1.0
    ]

    assert {:ok, first} =
             EntitySupervisor.sensorimotor_cycle(
               id,
               [{:visual_channel, :stimulus_relation, :near}],
               1,
               feedback,
               opts
             )

    assert {:ok, second} =
             EntitySupervisor.sensorimotor_cycle(
               id,
               [{:visual_channel, :stimulus_relation, :near}],
               2,
               feedback,
               opts
             )

    assert first.entity_id == id
    assert second.trace.cycles == 2
    assert second.trace.motor_attempts == 2
    assert second.trace.learned_output_edges > 0
    refute Map.has_key?(second.outcome, :action)
  end

  test "sensorimotor geometry survives an OTP entity restart", %{id: id} do
    assert {:ok, entity_pid} =
             EntitySupervisor.start_npc(id, %{
               sensorimotor: [
                 field_opts: [
                   micro_nodes: 64,
                   input_width: 3,
                   encoding_salt: {:restart_loop, id},
                   output_source_threshold: 0.0
                 ],
                 body_opts: [initial_coordination: 1.0],
                 position: {1, 1}
               ]
             })

    feedback = fn outcome, position ->
      {[{:motor_consequence, outcome.consequence}, {:position, position}], 1.0}
    end

    assert {:ok, before_restart} =
             EntitySupervisor.sensorimotor_cycle(
               id,
               [{:stimulus, :near}],
               1,
               feedback,
               seed: 3,
               bounds: {3, 3},
               output_exploration: 1.0
             )

    sensorimotor_pid = GenServer.whereis(LiveSensorimotor.via_tuple(id))
    Process.exit(entity_pid, :kill)

    assert_eventually(fn ->
      case EntitySupervisor.lookup_entity(id) do
        {:ok, replacement_pid} -> replacement_pid != entity_pid and Process.alive?(replacement_pid)
        _ -> false
      end
    end)

    assert_eventually(fn ->
      case EntitySupervisor.sensorimotor_trace(id) do
        {:ok, trace} -> trace.attached? and trace.cycles == before_restart.trace.cycles
        _ -> false
      end
    end)

    assert GenServer.whereis(LiveSensorimotor.via_tuple(id)) == sensorimotor_pid

    assert {:ok, after_restart} =
             EntitySupervisor.sensorimotor_cycle(
               id,
               [{:stimulus, :near}],
               2,
               feedback,
               seed: 3,
               bounds: {3, 3},
               output_exploration: 1.0
             )

    assert after_restart.trace.cycles == before_restart.trace.cycles + 1
  end

  test "stopping an entity also stops its sensorimotor owner", %{id: id} do
    assert {:ok, _pid} =
             EntitySupervisor.start_npc(id, %{
               sensorimotor: [position: {1, 1}]
             })

    assert EntitySupervisor.sensorimotor_enabled?(id)
    assert :ok = EntitySupervisor.stop_entity(id)

    assert_eventually(fn ->
      not EntitySupervisor.exists?(id) and not EntitySupervisor.sensorimotor_enabled?(id)
    end)
  end

  test "entity listings exclude subsystem registry entries", %{id: id} do
    assert {:ok, pid} =
             EntitySupervisor.start_npc(id, %{
               sensorimotor: [position: {1, 1}]
             })

    assert {id, pid} in EntitySupervisor.list_entities()
    refute Enum.any?(EntitySupervisor.list_entities(), fn {listed_id, _pid} ->
             match?({:sensorimotor, _}, listed_id)
           end)
  end

  defp assert_eventually(predicate, attempts \\ 100)
  defp assert_eventually(predicate, 0), do: assert(predicate.())

  defp assert_eventually(predicate, attempts) do
    if predicate.() do
      assert true
    else
      Process.sleep(10)
      assert_eventually(predicate, attempts - 1)
    end
  end
end
