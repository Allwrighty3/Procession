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
    assert prompt =~ "Player message:"
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
end
