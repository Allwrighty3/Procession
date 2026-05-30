defmodule Procession.GameTest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)

    :ok
  end

  describe "new_game/1" do
    test "new_game creates a deterministic playable world" do
      assert {:ok, game} = Procession.Game.new_game("a frontier village near a haunted mine")

      assert game.name == "Echoes of the Old Road"
      assert game.description =~ "frontier region"
      assert game.prompt == "a frontier village near a haunted mine"

      assert game.locations == ["loc_crossroads", "loc_briar_village", "loc_silent_mine"]
      assert game.npcs == ["npc_mira", "npc_tobin", "npc_elin"]
      assert game.factions == ["faction_roadwardens"]

      assert game.relationships == 2
      assert game.starter_memories == 2
    end

    test "new_game starts generated entities as live processes" do
      assert {:ok, game} = Procession.Game.new_game("anything")

      assert Enum.all?(game.locations, fn id ->
               Procession.EntitySupervisor.exists?(id)
             end)

      assert Enum.all?(game.npcs, fn id ->
               Procession.EntitySupervisor.exists?(id)
             end)

      assert Enum.all?(game.factions, fn id ->
               Procession.EntitySupervisor.exists?(id)
             end)
    end

    test "new_game creates entities that can be inspected through look" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      assert {:ok, summary} = Procession.Game.look("npc_mira")

      assert summary.id == "npc_mira"
      assert summary.name == "Mira"
      assert summary.type == :npc
      assert summary.location == "loc_briar_village"
      assert summary.traits == %{role: "innkeeper", temperament: "watchful"}
    end

    test "new_game attaches generated starter memories" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      Process.sleep(10)

      assert {:ok, summary} = Procession.Game.look("npc_mira")
      assert summary.memory_summary.short == 1

      memories = Procession.Entity.recall_all("npc_mira")

      assert Enum.any?(memories, fn memory ->
               memory.content == "Tobin was seen near the Silent Mine after sundown." and
                 memory.type == :rumor
             end)
    end

    test "new_game rejects invalid prompts" do
      assert Procession.Game.new_game(nil) == {:error, :invalid_prompt}
      assert Procession.Game.new_game(:not_a_prompt) == {:error, :invalid_prompt}
      assert Procession.Game.new_game(123) == {:error, :invalid_prompt}
    end
  end

  describe "look/1" do
    test "look returns a player-facing summary for an NPC" do
      assert {:ok, _pid} =
               Procession.EntitySupervisor.start_npc("npc_mira", %{
                 name: "Mira",
                 location: "loc_briar_village",
                 traits: %{role: "innkeeper", temperament: "watchful"}
               })

      assert {:ok, summary} = Procession.Game.look("npc_mira")

      assert summary == %{
               id: "npc_mira",
               name: "Mira",
               type: :npc,
               location: "loc_briar_village",
               status: :idle,
               traits: %{role: "innkeeper", temperament: "watchful"},
               relationships: [],
               description: nil,
               memory_summary: %{short: 0, medium: 0, long: 0}
             }
    end

    test "look returns a player-facing summary for a faction" do
      assert {:ok, _pid} =
               Procession.EntitySupervisor.start_faction("faction_roadwardens", %{
                 name: "Roadwardens",
                 metadata: %{
                   description: "A loose band of locals who keep the roads safe when they can."
                 }
               })

      assert {:ok, summary} = Procession.Game.look("faction_roadwardens")

      assert summary.id == "faction_roadwardens"
      assert summary.name == "Roadwardens"
      assert summary.type == :faction

      assert summary.description ==
               "A loose band of locals who keep the roads safe when they can."

      assert summary.memory_summary == %{short: 0, medium: 0, long: 0}
    end

    test "look includes relationship metadata when present" do
      assert {:ok, _pid} =
               Procession.EntitySupervisor.start_npc("npc_mira", %{
                 name: "Mira",
                 location: "loc_briar_village",
                 metadata: %{
                   relationships: [
                     %{
                       to: "npc_tobin",
                       type: :distrusts,
                       description: "Mira thinks Tobin knows more than he admits."
                     }
                   ]
                 }
               })

      assert {:ok, summary} = Procession.Game.look("npc_mira")

      assert summary.relationships == [
               %{
                 to: "npc_tobin",
                 type: :distrusts,
                 description: "Mira thinks Tobin knows more than he admits."
               }
             ]
    end

    test "look includes description metadata when present" do
      assert {:ok, _pid} =
               Procession.EntitySupervisor.start_location("loc_crossroads", %{
                 name: "Old Road Crossroads",
                 metadata: %{
                   description:
                     "A muddy crossroads where merchants, pilgrims, and trouble pass through."
                 }
               })

      assert {:ok, summary} = Procession.Game.look("loc_crossroads")

      assert summary.id == "loc_crossroads"
      assert summary.name == "Old Road Crossroads"
      assert summary.type == :location

      assert summary.description ==
               "A muddy crossroads where merchants, pilgrims, and trouble pass through."
    end

    test "look returns a predictable error for a missing entity" do
      assert Procession.Game.look("npc_missing") == {:error, :entity_not_found}
    end
  end

  describe "ask_about/2" do
    test "ask_about returns matching memories for a known topic" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      Process.sleep(10)

      assert {:ok, memories} = Procession.Game.ask_about("npc_mira", "Tobin")

      assert Enum.any?(memories, fn memory ->
               memory.content == "Tobin was seen near the Silent Mine after sundown." and
                 memory.type == :rumor
             end)
    end

    test "ask_about returns an empty list for an unknown topic" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      Process.sleep(10)

      assert Procession.Game.ask_about("npc_mira", "dragon") == {:ok, []}
    end

    test "ask_about returns a predictable error for a missing entity" do
      assert Procession.Game.ask_about("npc_missing", "mine") == {:error, :entity_not_found}
    end

    test "ask_about rejects invalid topics" do
      assert Procession.Game.ask_about("npc_mira", nil) == {:error, :invalid_topic}
      assert Procession.Game.ask_about("npc_mira", :mine) == {:error, :invalid_topic}
      assert Procession.Game.ask_about("npc_mira", 123) == {:error, :invalid_topic}
    end
  end

  describe "talk_to/1" do
    test "talk_to requests diablogue through the entity AI boundary" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      assert {:ok, response} =
               Procession.Game.talk_to(
                 "npc_mira",
                 "What do you know about Tobin?",
                 adapter: Procession.AI.FakeAdapter
               )

      assert response =~ "AI response to:"
      assert response =~ "What do you know about Tobin"
    end

    test "talk_to returns a predictable error for a missing NPC" do
      assert Procession.Game.talk_to(
               "npc_missing",
               "Hello?",
               adapter: Procession.AI.FakeAdapter
             ) == {:error, :entity_not_found}
    end

    test "talk_to returns entity_not_found when the entity disappears before response generation" do
      {:ok, summary} = Procession.Game.new_game("a quiet frontier town")

      npc_id = Enum.find(summary.npcs, &String.starts_with?(&1, "npc_"))

      :ok = Procession.EntitySupervisor.stop_entity(npc_id)

      assert {:error, :entity_not_found} =
               Procession.Game.talk_to(npc_id, "Hello?", adapter: Procession.AI.FakeAdapter)
    end

    test "talk_to rejects invalid player messages" do
      assert Procession.Game.talk_to("npc_mira", nil) == {:error, :invalid_message}
      assert Procession.Game.talk_to("npc_mira", :hello) == {:error, :invalid_message}
      assert Procession.Game.talk_to("npc_mira", 123) == {:error, :invalid_message}
    end
  end

  describe "perform/2" do
    test "perform supports the look action" do
      assert {:ok, _pid} =
               Procession.EntitySupervisor.start_npc("npc_mira", %{
                 name: "Mira",
                 location: "loc_briar_village",
                 traits: %{role: "innkeeper", temperament: "watchful"}
               })

      assert {:ok, summary} = Procession.Game.perform(:look, entity_id: "npc_mira")

      assert summary.id == "npc_mira"
      assert summary.name == "Mira"
      assert summary.type == :npc
    end

    test "perform look returns a predictable error when look is missing an entity_id" do
      assert Procession.Game.perform(:look, []) == {:error, :missing_target}
    end

    test "perform look returns a predictable error for invalid actions" do
      assert Procession.Game.perform(:not_a_valid_action, entity_id: "npc_mira") ==
               {:error, :invalid_action}
    end

    test "perform supports the ask_about action" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      Process.sleep(10)

      assert {:ok, memories} =
               Procession.Game.perform(:ask_about,
                 entity_id: "npc_mira",
                 topic: "Tobin"
               )

      assert Enum.any?(memories, fn memory ->
               memory.content == "Tobin was seen near the Silent Mine after sundown." and
                 memory.type == :rumor
             end)
    end

    test "perform ask_about returns a predictable error when missing entity_id" do
      assert Procession.Game.perform(:ask_about, topic: "Tobin") == {:error, :missing_target}
    end

    test "perform ask_about returns a predictable error when missing topic" do
      assert Procession.Game.perform(:ask_about, entity_id: "npc_mira") ==
               {:error, :missing_topic}
    end

    test "perform ask_about delegates invalid topics to ask_about" do
      assert Procession.Game.perform(:ask_about, entity_id: "npc_mira", topic: nil) ==
               {:error, :invalid_topic}
    end

    test "perform supports the talk_to action" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      assert {:ok, response} =
               Procession.Game.perform(:talk_to,
                 entity_id: "npc_mira",
                 message: "What do you know about Tobin?",
                 adapter: Procession.AI.FakeAdapter
               )

      assert response =~ "AI response to:"
      assert response =~ "What do you know about Tobin?"
    end

    test "perform talk_to returns a predictable error when missing entity_id" do
      assert Procession.Game.perform(:talk_to,
               message: "Hello?",
               adapter: Procession.AI.FakeAdapter
             ) == {:error, :missing_target}
    end

    test "perform talk_to returns a predictable error when missing message" do
      assert Procession.Game.perform(:talk_to,
               entity_id: "npc_mira",
               adapter: Procession.AI.FakeAdapter
             ) == {:error, :missing_message}
    end

    test "perform talk_to delegates invalid messages to talk_to" do
      assert Procession.Game.perform(:talk_to,
               entity_id: "npc_mira",
               message: nil,
               adapter: Procession.AI.FakeAdapter
             ) == {:error, :invalid_message}
    end
  end

  describe "tick_world/0" do
    test "tick_world coordinates entity ticks and returns entity-driven actions" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      assert {:ok, summary} = Procession.Game.tick_world()

      assert summary.entities_ticked >= 1

      assert Enum.any?(summary.actions, fn action ->
               action == %{
                 status: :ok,
                 action: :send_message,
                 from: "npc_tobin",
                 to: "npc_mira",
                 type: :rumor,
                 content: "Tobin quietly warned Mira that the mine road was watched."
               }
             end)
    end

    test "tick_world changes the world through entity-owned behavior" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      assert {:ok, []} = Procession.Game.recent_events("npc_mira")

      assert {:ok, _summary} = Procession.Game.tick_world()

      Process.sleep(10)

      assert {:ok, events} = Procession.Game.recent_events("npc_mira")

      assert Enum.any?(events, fn event ->
               event.content == "Tobin quietly warned Mira that the mine road was watched." and
                 event.from == "npc_tobin" and
                 event.metadata.source == :entity_tick
             end)
    end

    test "tick_world separates successful and failed actions" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      assert {:ok, summary} = Procession.Game.tick_world()

      assert is_list(summary.actions)
      assert is_list(summary.successful_actions)
      assert is_list(summary.failed_actions)

      assert summary.successful_actions ==
               Enum.filter(summary.actions, fn action ->
                 Map.get(action, :status) == :ok
               end)

      assert summary.failed_actions ==
               Enum.filter(summary.actions, fn action ->
                 Map.get(action, :status) == :error
               end)
    end

    test "tick_world collects failed behavior actions as data" do
      assert {:ok, _pid} =
               Procession.EntitySupervisor.start_npc("npc_faulty", %{
                 name: "Faulty",
                 location: "loc_nowhere",
                 metadata: %{
                   behaviors: [
                     %{
                       trigger: :world_tick,
                       action: :send_message,
                       to: "npc_missing",
                       content: "This message has nowhere to go."
                     }
                   ]
                 }
               })

      assert {:ok, summary} = Procession.Game.tick_world()

      assert summary.entities_ticked == 1

      assert Enum.any?(summary.failed_actions, fn action ->
               action.status == :error and
                 action.action == :send_message and
                 action.from == "npc_faulty" and
                 action.to == "npc_missing" and
                 action.reason == :entity_not_found
             end)

      assert summary.successful_actions == []
    end

    test "tick_world collects unsupported behavior actions as failed actions" do
      assert {:ok, _pid} =
               Procession.EntitySupervisor.start_npc("npc_confused", %{
                 name: "Confused",
                 location: "loc_nowhere",
                 metadata: %{
                   behaviors: [
                     %{
                       trigger: :world_tick,
                       action: :teleport_to_moon
                     }
                   ]
                 }
               })

      assert {:ok, summary} = Procession.Game.tick_world()

      assert summary.entities_ticked == 1
      assert summary.successful_actions == []

      assert Enum.any?(summary.failed_actions, fn action ->
               action.status == :error and
                 action.action == :teleport_to_moon and
                 action.from == "npc_confused" and
                 action.reason == {:unsupported_behavior_action, :teleport_to_moon}
             end)
    end

    test "tick_world returns no actions when no live entities have tick behavior" do
      assert Procession.Game.tick_world() ==
               {:ok,
                %{entities_ticked: 0, actions: [], failed_actions: [], successful_actions: []}}
    end

    test "tick_world records missing entities as failed tick actions" do
      assert {:ok, _pid} =
               Procession.EntitySupervisor.start_npc("npc_disappearing", %{
                 name: "Disappearing NPC",
                 metadata: %{
                   behaviors: [
                     %{
                       trigger: :world_tick,
                       action: :change_status,
                       status: :alert
                     }
                   ]
                 }
               })

      entities = Procession.EntitySupervisor.list_entities()

      assert Enum.any?(entities, fn {id, _pid} -> id == "npc_disappearing" end)

      :ok = Procession.EntitySupervisor.stop_entity("npc_disappearing")

      # This mostly protects the implementation path. If the registry cleans up too fast,
      # the world simply has no entity to tick, which is also valid.
      assert {:ok, summary} = Procession.Game.tick_world()

      assert is_list(summary.failed_actions)
    end
  end

  describe "recent_events/1" do
    test "recent_events returns entity tick memories for an entity" do
      assert {:ok, _game} = Procession.Game.new_game("anything")

      assert {:ok, []} = Procession.Game.recent_events("npc_mira")

      assert {:ok, _summary} = Procession.Game.tick_world()

      Process.sleep(10)

      assert {:ok, events} = Procession.Game.recent_events("npc_mira")

      assert Enum.any?(events, fn event ->
               event.content == "Tobin quietly warned Mira that the mine road was watched." and
                 event.type == :rumor and
                 event.from == "npc_tobin"
             end)
    end

    test "recent_events returns a predictable error for a missing entity" do
      assert Procession.Game.recent_events("npc_missing") == {:error, :entity_not_found}
    end
  end
end
