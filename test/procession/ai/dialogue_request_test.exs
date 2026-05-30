defmodule Procession.AI.DialogueRequestTest do
  use ExUnit.Case

  alias Procession.AI.DialogueRequest
  alias Procession.Entity

  test "builds structured dialogue request from entity state and validated context" do
    state = %Entity{
      id: "npc_mira",
      name: "Mira",
      type: :npc,
      status: :watching,
      location: "loc_briar_village",
      traits: %{role: "innkeeper"}
    }

    memories = [
      %{content: "Tobin was seen near the Silent Mine.", type: :rumor, importance: 3}
    ]

    assert {:ok, request} =
             DialogueRequest.from_entity_state(
               state,
               "What do you know about Tobin?",
               memories,
               location_context: %{name: "Briar Village"},
               world_context: %{tone: "uneasy frontier"}
             )

    assert request.npc == %{
             id: "npc_mira",
             name: "Mira",
             type: :npc,
             status: :watching,
             location: "loc_briar_village",
             traits: %{role: "innkeeper"}
           }

    assert request.message == "What do you know about Tobin?"

    assert request.speaker == %{
             id: "player",
             type: :player,
             name: "Player"
           }

    assert request.relevant_memories == memories
    assert request.location_context == %{name: "Briar Village"}
    assert request.world_context == %{tone: "uneasy frontier"}
  end

  test "builds dialogue request with an explicit non-player speaker" do
    state = %Entity{
      id: "npc_mira",
      name: "Mira",
      type: :npc,
      status: :watching,
      location: "loc_briar_village",
      traits: %{role: "innkeeper"}
    }

    assert {:ok, request} =
             DialogueRequest.from_entity_state(
               state,
               "The road is watched.",
               [],
               speaker: %{
                 id: "npc_tobin",
                 type: :npc,
                 name: "Tobin"
               }
             )

    assert request.speaker == %{
             id: "npc_tobin",
             type: :npc,
             name: "Tobin"
           }

    assert request.message == "The road is watched."
  end

  test "rejects invalid dialogue request inputs" do
    assert {:error, :invalid_dialogue_request} = DialogueRequest.from_entity_state(%{}, nil, [])
  end
end
