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

    assert request.player_message == "What do you know about Tobin?"
    assert request.relevant_memories == memories
    assert request.location_context == %{name: "Briar Village"}
    assert request.world_context == %{tone: "uneasy frontier"}
  end

  test "rejects invalid dialogue request inputs" do
    assert {:error, :invalid_dialogue_request} = DialogueRequest.from_entity_state(%{}, nil, [])
  end
end
