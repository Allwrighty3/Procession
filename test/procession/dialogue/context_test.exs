defmodule Procession.Dialogue.ContextTest do
  use ExUnit.Case, async: false

  alias Procession.Dialogue.Context
  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.GameSession

  setup do
    on_exit(fn ->
      Enum.each(EntitySupervisor.list_entities(), fn {id, _pid} ->
        EntitySupervisor.stop_entity(id)
      end)
    end)
  end

  test "builds grounded dialogue context from a live game session" do
    assert {:ok, demo} = GameSession.start_demo("a quiet frontier town")

    assert {:ok, context} =
             Context.from_session(
               demo.session,
               "npc_tobin",
               "Who is Mira?",
               memory_query: "mine"
             )

    assert context.target == %{
             id: "npc_tobin",
             name: "Tobin",
             type: :npc,
             status: :idle,
             location: "loc_crossroads",
             traits: %{role: "merchant", temperament: "nervous"}
           }

    assert context.speaker == %{
             id: "player_main",
             name: "Player",
             type: :player
           }

    assert context.message == "Who is Mira?"

    assert context.location.id == "loc_crossroads"
    assert context.location.name == "Old Road Crossroads"
    assert context.location.type == :location
    assert context.location.description =~ "muddy crossroads"

    assert Enum.any?(context.location.exits, fn exit ->
             exit.to == "loc_briar_village" and exit.label == "village road"
           end)

    assert Enum.any?(context.active_entities, fn entity ->
             entity.id == "npc_mira" and
               entity.name == "Mira" and
               entity.type == :npc and
               entity.location == "loc_briar_village" and
               entity.traits.role == "innkeeper"
           end)

    assert Enum.any?(context.target_memories, fn memory ->
             memory.content =~ "old road" or memory.content =~ "mine"
           end)
  end

  test "rejects a target entity outside the session" do
    assert {:ok, demo} = GameSession.start_demo("a quiet frontier town")

    assert Context.from_session(
             demo.session,
             "npc_not_real",
             "Hello?"
           ) == {:error, :entity_not_in_session}
  end

  test "does not mutate target memory while building context" do
    assert {:ok, demo} = GameSession.start_demo("a quiet frontier town")

    before_memories = Entity.recall_all("npc_tobin")

    assert {:ok, _context} =
             Context.from_session(
               demo.session,
               "npc_tobin",
               "What is happening on the road?"
             )

    after_memories = Entity.recall_all("npc_tobin")

    assert after_memories == before_memories
  end

  test "rejects invalid context inputs" do
    assert Context.from_session(:not_a_session, "npc_tobin", "Hello") ==
             {:error, :invalid_dialogue_context}

    assert Context.from_session(self(), :bad_target, "Hello") ==
             {:error, :invalid_dialogue_context}

    assert Context.from_session(self(), "npc_tobin", nil) ==
             {:error, :invalid_dialogue_context}
  end
end
