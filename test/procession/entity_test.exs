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

  test "sending a message to a missing entity returns an error" do
    result =
      Procession.Entity.send_to(:sender_test_npc, :missing_receiver_test_npc, %{
        content: "Hello?"
      })

    assert result == {:error, :entity_not_found}
  end

  test "failed message delivery does not create an entity" do
    refute Procession.EntitySupervisor.exists?(:_missing_receiver_side_effect_test)

    assert {:error, :entity_not_found} =
             Procession.Entity.send_to(:sender_test_npc, :missing_receiver_side_effect_test, %{
               content: "Hello?"
             })

    refute Procession.EntitySupervisor.exists?(:missing_receiver_side_effect_test)
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

  test "short memory keeps only the 10 most recent messages" do
    id = :memory_limit_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Memory Tester",
        type: :npc,
        location: :test_room
      })

    for n <- 1..12 do
      Procession.Entity.send_message(id, %{
        from: :player,
        type: :dialogue,
        content: "Message #{n}"
      })
    end

    Process.sleep(20)

    state = Procession.Entity.get_state(id)

    assert length(state.short_memory) == 10
    assert hd(state.short_memory).content == "Message 12"
    assert List.last(state.short_memory).content == "Message 3"
  end

  test "overflowed short memories move into medium memory" do
    id = :memory_promotion_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Memory Promotion Tester",
        type: :npc,
        location: :test_room
      })

    for n <- 1..12 do
      Procession.Entity.send_message(id, %{
        from: :player,
        type: :dialogue,
        content: "Message #{n}"
      })
    end

    Process.sleep(20)

    state = Procession.Entity.get_state(id)

    assert length(state.short_memory) == 10
    assert length(state.medium_memory) == 2

    assert hd(state.short_memory).content == "Message 12"
    assert List.last(state.short_memory).content == "Message 3"

    assert Enum.map(state.medium_memory, & &1.content) == [
             "Message 2",
             "Message 1"
           ]
  end

  test "medium memory keeps only the 50 most recent promoted memories" do
    id = :medium_memory_limit_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Medium Memory Tester",
        type: :npc,
        location: :test_room
      })

    for n <- 1..65 do
      Procession.Entity.send_message(id, %{
        from: :player,
        type: :dialogue,
        content: "Message #{n}"
      })
    end

    Process.sleep(50)

    state = Procession.Entity.get_state(id)

    assert length(state.short_memory) == 10
    assert length(state.medium_memory) == 50
  end

  test "medium memory overflow moves into long memory" do
    id = :long_memory_promotion_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Long Memory Tester",
        type: :npc,
        location: :test_room
      })

    for n <- 1..65 do
      Procession.Entity.send_message(id, %{
        from: :player,
        type: :dialogue,
        content: "Message #{n}"
      })
    end

    Process.sleep(50)

    state = Procession.Entity.get_state(id)

    assert length(state.short_memory) == 10
    assert length(state.medium_memory) == 50
    assert length(state.long_memory) == 5
  end

  test "long memory keeps only the 200 most recent promoted memories" do
    id = :long_memory_limit_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Long Memory Limit Tester",
        type: :npc,
        location: :test_room
      })

    for n <- 1..265 do
      Procession.Entity.send_message(id, %{
        from: :player,
        type: :dialogue,
        content: "Message #{n}"
      })
    end

    Process.sleep(100)

    state = Procession.Entity.get_state(id)

    assert length(state.short_memory) == 10
    assert length(state.medium_memory) == 50
    assert length(state.long_memory) == 200
  end

  test "entity can recall memories by keyword" do
    id = :recall_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "The blacksmith lost his hammer"
    })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "The baker needs flour"
    })

    Process.sleep(20)

    assert [
             %{
               from: :player,
               type: :dialogue,
               content: "The blacksmith lost his hammer",
               importance: 1,
               timestamp: timestamp
             }
           ] = Procession.Entity.recall(id, "hammer")

    assert %DateTime{} = timestamp
  end

  test "entity can recall memories by type" do
    id = :recall_by_type_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall by Type Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "The blacksmith lost his hammer"
    })

    Procession.Entity.send_message(id, %{
      from: :system,
      type: :event,
      content: "A storm begins over the village"
    })

    Process.sleep(20)

    memories = Procession.Entity.recall_by_type(id, :dialogue)

    assert Enum.map(memories, & &1.content) == [
             "The blacksmith lost his hammer"
           ]

    assert Enum.all?(memories, fn memory ->
             memory.type == :dialogue
           end)
  end

  test "entity can recall important memories" do
    id = :recall_important_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall Important Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      importance: 1,
      content: "A casual greeting"
    })

    Procession.Entity.send_message(id, %{
      from: :system,
      type: :event,
      importance: 5,
      content: "The village is under attack"
    })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      importance: 3,
      content: "The blacksmith knows a secret"
    })

    Process.sleep(20)

    memories = Procession.Entity.recall_important(id, 3)

    assert Enum.map(memories, & &1.content) == [
             "The blacksmith knows a secret",
             "The village is under attack"
           ]

    assert Enum.all?(memories, fn memory ->
             memory.importance >= 3
           end)
  end

  test "entity can recall recent memories" do
    id = :recall_recent_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall Recent Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "First memory"
    })

    Procession.Entity.send_message(id, %{
      from: :system,
      type: :dialogue,
      content: "Second memory"
    })

    Procession.Entity.send_message(id, %{
      from: :system,
      type: :dialogue,
      content: "Third memory"
    })

    Process.sleep(20)

    memories = Procession.Entity.recall_recent(id, 2)

    assert Enum.map(memories, & &1.content) == [
             "Third memory",
             "Second memory"
           ]
  end

  test "entity can recall all memories in priority order" do
    id = :recall_all_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall All Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "First memory"
    })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "Second memory"
    })

    Process.sleep(20)

    memories = Procession.Entity.recall_all(id)

    assert Enum.map(memories, & &1.content) == [
             "Second memory",
             "First memory"
           ]
  end

  test "can check whether an entity exists" do
    id = :exists_test_npc

    refute Procession.EntitySupervisor.exists?(id)

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Exists Tester",
        type: :npc,
        location: :test_room
      })

    assert Procession.EntitySupervisor.exists?(id)
  end

  test "can stop an entity" do
    id = :stop_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Stop Tester",
        type: :npc,
        location: :test_room
      })

    assert Procession.EntitySupervisor.exists?(id)
    assert :ok = Procession.EntitySupervisor.stop_entity(id)

    Process.sleep(20)

    refute Procession.EntitySupervisor.exists?(id)
  end

  test "entity can summarize memory counts" do
    id = :memory_summary_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Memory Summary Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "Remember this."
    })

    Process.sleep(20)

    assert Procession.Entity.memory_summary(id) == %{
             short: 1,
             medium: 0,
             long: 0
           }
  end

  test "entity can recall memories by sender" do
    id = :recall_by_sender_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall By Sender Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "The player said hello"
    })

    Procession.Entity.send_message(id, %{
      from: :system,
      type: :event,
      content: "A storm begins"
    })

    Process.sleep(20)

    memories = Procession.Entity.recall_by_sender(id, :player)

    assert Enum.map(memories, & &1.content) == [
             "The player said hello"
           ]

    assert Enum.all?(memories, fn memory ->
             memory.from == :player
           end)
  end

  test "entity can recall memories by tag" do
    id = :recall_by_tag_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall By Tag Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "The blacksmith lost his hammer",
      tags: [:quest, :blacksmith]
    })

    Procession.Entity.send_message(id, %{
      from: :system,
      type: :event,
      content: "A storm begins",
      tags: [:weather]
    })

    Process.sleep(20)

    memories = Procession.Entity.recall_by_tag(id, :quest)

    assert Enum.map(memories, & &1.content) == [
             "The blacksmith lost his hammer"
           ]

    assert Enum.all?(memories, fn memory ->
             :quest in memory.tags
           end)
  end

  test "entity can recall memories by metadata value" do
    id = :recall_by_metadata_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall By Metadata Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "The blacksmith lost his hammer",
      metadata: %{location: :village_square}
    })

    Procession.Entity.send_message(id, %{
      from: :system,
      type: :event,
      content: "A storm begins",
      metadata: %{location: :forest}
    })

    Process.sleep(20)

    memories = Procession.Entity.recall_by_metadata(id, :location, :village_square)

    assert Enum.map(memories, & &1.content) == [
             "The blacksmith lost his hammer"
           ]
  end

  test "entity can recall memories by metadata list membership" do
    id = :recall_by_metadata_list_test_npc

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "Recall By Metadata List Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: :player,
      type: :dialogue,
      content: "The blacksmith lost his hammer",
      metadata: %{related_entities: [:blacksmith, :player]}
    })

    Procession.Entity.send_message(id, %{
      from: :system,
      type: :event,
      content: "A storm begins",
      metadata: %{related_entities: [:weather]}
    })

    Process.sleep(20)

    memories =
      Procession.Entity.recall_by_metadata(
        id,
        :related_entities,
        :blacksmith
      )

    assert Enum.map(memories, & &1.content) == [
             "The blacksmith lost his hammer"
           ]
  end

  test "entity can be started with a string ID" do
    id = "npc_string_id_test"

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "String ID Tester",
        type: :npc,
        location: :test_room
      })

    assert Procession.EntitySupervisor.exists?(id)
  end

  test "entity with string ID can receive messages" do
    id = "npc_string_message_test"

    {:ok, _pid} =
      Procession.EntitySupervisor.start_entity(id, %{
        name: "String Message Tester",
        type: :npc,
        location: :test_room
      })

    Procession.Entity.send_message(id, %{
      from: "player_test",
      type: :dialogue,
      content: "Hello from a string ID"
    })

    Process.sleep(20)

    memories = Procession.Entity.recall_all(id)

    assert Enum.map(memories, & &1.content) == [
             "Hello from a string ID"
           ]

    assert hd(memories).from == "player_test"
  end

  test "entity with string ID can send to another string ID entity" do
    sender_id = "npc_string_sender_test"
    receiver_id = "npc_string_receiver_test"

    {:ok, _sender_pid} =
      Procession.EntitySupervisor.start_entity(sender_id, %{
        name: "String Sender",
        type: :npc,
        location: :test_room
      })

    {:ok, _receiver_pid} =
      Procession.EntitySupervisor.start_entity(receiver_id, %{
        name: "String Receiver",
        type: :npc,
        location: :test_room
      })

    assert :ok =
             Procession.Entity.send_to(sender_id, receiver_id, %{
               type: :dialogue,
               content: "String IDs work"
             })

    Process.sleep(20)

    memories = Procession.Entity.recall_all(receiver_id)

    assert Enum.map(memories, & &1.content) == [
             "String IDs work"
           ]

    assert hd(memories).from == sender_id
  end

  test "can start an NPC with convenience helper" do
    id = "npc_helper_test"

    {:ok, _pid} =
      Procession.EntitySupervisor.start_npc(id, %{
        name: "Helper NPC",
        location: "loc_test_room"
      })

    state = Procession.Entity.get_state(id)

    assert state.id == id
    assert state.name == "Helper NPC"
    assert state.type == :npc
    assert state.location == "loc_test_room"
  end

  test "can start a location with convenience helper" do
    id = "loc_helper_test"

    {:ok, _pid} =
      Procession.EntitySupervisor.start_location(id, %{
        name: "Test Room"
      })

    state = Procession.Entity.get_state(id)

    assert state.id == id
    assert state.name == "Test Room"
    assert state.type == :location
  end

  test "can start a faction with convenience helper" do
    id = "faction_helper_test"

    {:ok, _pid} =
      Procession.EntitySupervisor.start_faction(id, %{
        name: "Test Faction"
      })

    state = Procession.Entity.get_state(id)

    assert state.id == id
    assert state.name == "Test Faction"
    assert state.type == :faction
  end
end
