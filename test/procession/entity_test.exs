defmodule Procession.EntityTest do
  use ExUnit.Case

  test "entity stores received messages in short memory" do
    id = :test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Test NPC",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "Hello there."
    })

    Process.sleep(20)

    state = Procession.Entity.get_state(id)

    assert [%{content: "Hello there."}] = state.short_memory
  end

  test "one entity can send a message to another entity" do
    {:ok, _bob} =
      Procession.EntitySupervisor.start_entity(:bob_sender_test, %{
        name: "Bob",
        type: :npc,
        location: :village_square
      })

    {:ok, _alice} =
      Procession.EntitySupervisor.start_entity(:alice_receiver_test, %{
        name: "Alice",
        type: :npc,
        location: :village_square
      })

    Procession.Entity.send_to(:bob_sender_test, :alice_receiver_test, %{
      content: "Hello, Alice."
    })

    Process.sleep(20)

    alice_state = Procession.Entity.get_state(:alice_receiver_test)

    assert [
             %{
               from: :bob_sender_test,
               type: :message,
               content: "Hello, Alice."
             }
           ] = alice_state.short_memory
  end

  test "entity can update status and location" do
    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(:movement_test_npc, %{
        name: "Mira",
        type: :npc,
        location: :town_square
      })

    assert :ok = Procession.Entity.set_status(:movement_test_npc, :walking)
    assert :ok = Procession.Entity.move_to(:movement_test_npc, :blacksmith_shop)

    description = Procession.Entity.describe(:movement_test_npc)

    assert description == %{
             id: :movement_test_npc,
             name: "Mira",
             type: :npc,
             location: :blacksmith_shop,
             status: :walking
           }
  end
end
