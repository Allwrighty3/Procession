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

  test "grounded_npc_response builds a prompt from dialogue context" do
    prompt =
      Procession.AI.Prompt.grounded_npc_response(%{
        target: %{
          id: "npc_tobin",
          name: "Tobin",
          type: :npc,
          status: :idle,
          location: "loc_crossroads",
          traits: %{role: "merchant", temperament: "nervous"}
        },
        speaker: %{
          id: "player_main",
          name: "Player",
          type: :player
        },
        location: %{
          id: "loc_crossroads",
          name: "Old Road Crossroads",
          type: :location,
          description: "A muddy crossroads where merchants pass through.",
          exits: [
            %{to: "loc_briar_village", label: "village road"},
            %{to: "loc_silent_mine", label: "mine road"}
          ]
        },
        active_entities: [
          %{
            id: "player_main",
            name: "Player",
            type: :player,
            status: :idle,
            location: "loc_crossroads",
            traits: %{}
          },
          %{
            id: "npc_tobin",
            name: "Tobin",
            type: :npc,
            status: :idle,
            location: "loc_crossroads",
            traits: %{role: "merchant", temperament: "nervous"}
          },
          %{
            id: "npc_mira",
            name: "Mira",
            type: :npc,
            status: :idle,
            location: "loc_briar_village",
            traits: %{role: "innkeeper", temperament: "watchful"}
          }
        ],
        target_memories: [
          %{
            content: "The old road has been quieter since the mine started echoing again.",
            type: :observation,
            importance: 2
          }
        ],
        message: "Who is Mira?"
      })

    assert prompt =~ "Use only the grounded context below."

    assert prompt =~
             "Do not invent names, relationships, locations, occupations, memories, or events"

    assert prompt =~ "If the answer is not known from the context"

    assert prompt =~ "Target NPC:"
    assert prompt =~ "ID: npc_tobin"
    assert prompt =~ "Name: Tobin"
    assert prompt =~ "role: merchant"
    assert prompt =~ "temperament: nervous"

    assert prompt =~ "Speaker:"
    assert prompt =~ "ID: player_main"
    assert prompt =~ "Name: Player"

    assert prompt =~ "Current location:"
    assert prompt =~ "Old Road Crossroads"
    assert prompt =~ "village road -> loc_briar_village"
    assert prompt =~ "mine road -> loc_silent_mine"

    assert prompt =~ "Scene entities:"
    assert prompt =~ "Player (player_main, player) at loc_crossroads"
    assert prompt =~ "Tobin (npc_tobin, npc) at loc_crossroads"

    assert prompt =~ "Other known NPCs:"
    assert prompt =~ "Mira (npc_mira) is at loc_briar_village"
    assert prompt =~ "role: innkeeper"

    assert prompt =~ "Known locations:"
    assert prompt =~ "Known factions:"

    assert prompt =~ "Relevant target memories:"
    assert prompt =~ "old road has been quieter"

    assert prompt =~ "Player message:"
    assert prompt =~ "Who is Mira?"

    assert prompt =~ "Identity rule:"
    assert prompt =~ "You are Tobin and only Tobin."
    assert prompt =~ "Your entity ID is npc_tobin."
    assert prompt =~ "Do not claim to be any other entity listed in the context."
    assert prompt =~ "Listed entities are world facts, not your identity."

    assert prompt =~
             "If the player asks about another entity, describe that entity from the grounded context while continuing to speak as Tobin."

    assert prompt =~ "Grounding rule:"

    assert prompt =~
             "If the answer is not known from the context, respond with uncertainty in Tobin's voice."

    assert prompt =~ "Respond as Tobin in 1-3 sentences."
    assert prompt =~ "Do not start by saying you are another entity."
    assert prompt =~ "Only scene entities are physically present with Tobin."

    assert prompt =~
             "Other known NPCs are not at Tobin's location unless their location exactly matches Tobin's location."

    assert prompt =~
             "Do not infer plans, services, relationships, reputation, or current activity unless explicitly listed."
  end

  test "grounded_npc_response handles missing optional context" do
    prompt =
      Procession.AI.Prompt.grounded_npc_response(%{
        target: %{
          id: "npc_tobin",
          name: "Tobin",
          type: :npc,
          status: :idle,
          location: "loc_crossroads",
          traits: %{}
        },
        message: "Hello?"
      })

    assert prompt =~ "Name: Tobin"
    assert prompt =~ "Target traits:\n- none"
    assert prompt =~ "Current location:\n- none"
    assert prompt =~ "Scene entities:\n- none"
    assert prompt =~ "Other known NPCs:\n- none"
    assert prompt =~ "Known locations:\n- none"
    assert prompt =~ "Known factions:\n- none"
    assert prompt =~ "Relevant target memories:\n- none"
    assert prompt =~ "Hello?"
  end
end
