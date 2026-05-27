defmodule Procession.EntitySupervisorTest do
  use ExUnit.Case

  test "cannot start two entities with the same id" do
    id = :duplicate_id_test_npc

    {:ok, first_pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Original NPC",
        type: :npc,
        location: :town_square
      })

    assert {:error, {:already_started, ^first_pid}} =
             Procession.EntitySupervisor.start_entity(id, %{
               name: "Duplicate NPC",
               type: :npc,
               location: :forest
             })

    assert Procession.EntitySupervisor.exists?(id)

    description = Procession.Entity.describe(id)

    assert description.name == "Original NPC"
    assert description.location == :town_square
  end

  test "can look up an entity by id" do
    id = :lookup_test_npc

    {:ok, pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Lookup Tester",
        type: :npc,
        location: :test_room
      })

    assert Procession.EntitySupervisor.lookup_entity(id) == {:ok, pid}
  end

  test "looking up a missing entity returns not found" do
    assert Procession.EntitySupervisor.lookup_entity(:missing_lookup_test_npc) ==
             {:error, :not_found}
  end

  test "can list active entities" do
    {:ok, alpha_pid} =
      Procession.EntitySupervisor.start_entity(:list_test_alpha, %{
        name: "Alpha",
        type: :npc,
        location: :test_room
      })

    {:ok, beta_pid} =
      Procession.EntitySupervisor.start_entity(:list_test_beta, %{
        name: "Beta",
        type: :npc,
        location: :test_room
      })

    entities = Procession.EntitySupervisor.list_entities()

    assert {:list_test_alpha, alpha_pid} in entities
    assert {:list_test_beta, beta_pid} in entities
  end
end
