defmodule Procession.EntitySensorimotorIntegrationTest do
  use ExUnit.Case, async: false

  alias Procession.EntitySupervisor

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
    field_opts = [micro_nodes: 64, input_width: 3, encoding_salt: {:entity_loop, id}]

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

    opts =
      field_opts ++
        [
          seed: 7,
          bounds: {3, 3},
          output_exploration: 1.0,
          output_source_threshold: 0.0
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

  defp assert_eventually(predicate, attempts \\ 20)
  defp assert_eventually(predicate, 0), do: assert(predicate.())

  defp assert_eventually(predicate, attempts) do
    if predicate.() do
      assert true
    else
      Process.sleep(5)
      assert_eventually(predicate, attempts - 1)
    end
  end
end