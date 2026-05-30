defmodule Procession.AI.PromptTest do
  use ExUnit.Case

  test "npc_response builds a prompt from structured state" do
    prompt =
      Procession.AI.Prompt.npc_response(%{
        name: "Mira",
        status: :tired,
        location: "blacksmith_shop",
        traits: %{bravery: 7},
        memories: [
          %{content: "The blacksmith lost his hammer.", type: :dialogue, importance: 3}
        ],
        player_message: "Can you help me?"
      })

    assert prompt =~ "You are generating dialogue for a single-player RPG simulation."
    assert prompt =~ "Name: Mira"
    assert prompt =~ "Status: tired"
    assert prompt =~ "Location: blacksmith_shop"
    assert prompt =~ "- bravery: 7"
    assert prompt =~ "[dialogue, importance 3] The blacksmith lost his hammer."
    assert prompt =~ "Speaker:"
    assert prompt =~ "Message:"
    assert prompt =~ "Can you help me?"
    assert prompt =~ "Respond as the NPC in 1-3 sentences."
  end

  test "npc_response handles missing optional context" do
    prompt =
      Procession.AI.Prompt.npc_response(%{
        name: "Mira"
      })

    assert prompt =~ "Name: Mira"
    assert prompt =~ "Status: idle"
    assert prompt =~ "Location: unknown location"
    assert prompt =~ "Traits:\n- none"
    assert prompt =~ "Relevant memories:\n- none"
  end

  test "npc_response includes location context when provided" do
    prompt =
      Procession.AI.Prompt.npc_response(%{
        name: "Mira",
        location_context: %{
          name: "Briar Village",
          description: "A tense frontier settlement."
        },
        player_message: "What is happening here?"
      })

    assert prompt =~ "Current location context:"
    assert prompt =~ "Name: Briar Village"
    assert prompt =~ "Description: A tense frontier settlement."
  end

  test "npc_response includes explicit speaker context" do
    prompt =
      Procession.AI.Prompt.npc_response(%{
        name: "Mira",
        speaker: %{id: "npc_tobin", type: :npc, name: "Tobin"},
        message: "The road is watched."
      })

    assert prompt =~ "Speaker:"
    assert prompt =~ "Name: Tobin"
    assert prompt =~ "Type: npc"
    assert prompt =~ "ID: npc_tobin"
    assert prompt =~ "Message:"
    assert prompt =~ "The road is watched."
  end
end
