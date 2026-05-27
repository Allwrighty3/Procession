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
end
