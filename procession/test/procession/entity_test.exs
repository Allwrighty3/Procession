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
end
