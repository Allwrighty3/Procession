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

  test "talk_to rejects invalid player messages" do
    assert Procession.Game.talk_to("npc_mira", nil) == {:error, :invalid_message}
    assert Procession.Game.talk_to("npc_mira", :hello) == {:error, :invalid_message}
    assert Procession.Game.talk_to("npc_mira", 123) == {:error, :invalid_message}
  end

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
    assert Procession.Game.perform(:ask_about, entity_id: "npc_mira") == {:error, :missing_topic}
  end

  test "perform ask_about delegates invalid topics to ask_about" do
    assert Procession.Game.perform(:ask_about, entity_id: "npc_mira", topic: nil) ==
             {:error, :invalid_topic}
  end
end
