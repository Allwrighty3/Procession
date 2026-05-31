defmodule Procession.AI.NPCInteraction.ValidatorTest do
  use ExUnit.Case

  alias Procession.AI.NPCInteraction.Validator

  defp context do
    %{
      target: %{
        id: "npc_tobin",
        name: "Tobin",
        type: :npc,
        status: :idle,
        location: "loc_crossroads",
        traits: %{role: "merchant"}
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
        description: "A muddy crossroads.",
        exits: []
      },
      active_entities: [
        %{
          id: "npc_tobin",
          name: "Tobin",
          type: :npc,
          status: :idle,
          location: "loc_crossroads",
          traits: %{role: "merchant"}
        },
        %{
          id: "npc_mira",
          name: "Mira",
          type: :npc,
          status: :idle,
          location: "loc_briar_village",
          traits: %{role: "innkeeper"}
        }
      ],
      target_memories: [],
      message: "Who is Mira?"
    }
  end

  defp mira_context do
    %{
      target: %{
        id: "npc_mira",
        name: "Mira",
        type: :npc,
        status: :idle,
        location: "loc_briar_village",
        traits: %{role: "innkeeper"}
      },
      speaker: %{
        id: "player_main",
        name: "Player",
        type: :player
      },
      location: %{
        id: "loc_briar_village",
        name: "Briar Village",
        type: :location,
        description: "A small village near the old road.",
        exits: []
      },
      active_entities: [
        %{
          id: "npc_tobin",
          name: "Tobin",
          type: :npc,
          status: :idle,
          location: "loc_crossroads",
          traits: %{role: "merchant"}
        },
        %{
          id: "npc_mira",
          name: "Mira",
          type: :npc,
          status: :idle,
          location: "loc_briar_village",
          traits: %{role: "innkeeper"}
        }
      ],
      target_memories: [],
      message: "Who is Tobin?"
    }
  end

  test "accepts a non-empty response that preserves target identity" do
    response = "Mira runs the inn over in Briar Village, far as I know."

    assert Validator.validate_response(context(), response) == {:ok, response}
  end

  test "rejects a non-string response" do
    assert {:error, errors} = Validator.validate_response(context(), %{text: "hello"})

    assert [%{code: :invalid_response}] = errors
  end

  test "rejects a blank response" do
    assert {:error, errors} = Validator.validate_response(context(), "   ")

    assert Enum.any?(errors, &(&1.code == :blank_response))
  end

  test "rejects response where target claims to be another active NPC" do
    response = "I am Mira, and I run the inn."

    assert {:error, errors} = Validator.validate_response(context(), response)

    assert Enum.any?(errors, &(&1.code == :target_identity_violation))
  end

  test "rejects contraction identity claim for another active NPC" do
    response = "I'm Mira, and the village has been quiet."

    assert {:error, errors} = Validator.validate_response(context(), response)

    assert Enum.any?(errors, &(&1.code == :target_identity_violation))
  end

  test "rejects response where Mira claims to be Tobin" do
    response = "I am Tobin, and I have been watching the road."

    assert {:error, errors} = Validator.validate_response(mira_context(), response)

    assert Enum.any?(errors, &(&1.code == :target_identity_violation))
  end
end
