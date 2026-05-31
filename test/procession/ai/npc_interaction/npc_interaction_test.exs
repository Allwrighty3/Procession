defmodule Procession.AI.NPCInteractionTest do
  use ExUnit.Case

  alias Procession.AI.NPCInteraction

  defmodule EchoAdapter do
    def generate(prompt, _opts), do: {:ok, prompt}
  end

  defmodule ValidDialogueAdapter do
    def generate(_prompt, _opts) do
      {:ok, "Mira is over in Briar Village. I only know she keeps close watch on the place."}
    end
  end

  defmodule IdentityViolationAdapter do
    def generate(_prompt, _opts) do
      {:ok, "I am Mira, and I run the inn."}
    end
  end

  defp grounded_context do
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

  test "generate_response routes grounded context through the AI boundary" do
    assert {:ok, response} =
            NPCInteraction.generate_response(grounded_context(), adapter: EchoAdapter)

    assert response =~ "You are Tobin and only Tobin."
    assert response =~ "Your entity ID is npc_tobin."
    assert response =~ "Player message:"
    assert response =~ "Who is Mira?"
    assert response =~ "Use only the grounded context below."
  end

  test "generate_response rejects invalid context" do
    assert {:error, :invalid_npc_interaction_context} =
             NPCInteraction.generate_response("not context")
  end

  test "generate_response accepts validated NPC dialogue" do
    assert {:ok, response} =
            NPCInteraction.generate_response(grounded_context(),
              adapter: ValidDialogueAdapter
            )

    assert response ==
            "Mira is over in Briar Village. I only know she keeps close watch on the place."
  end

  test "generate_response rejects identity-violating NPC dialogue" do
    assert {:error, errors} =
            NPCInteraction.generate_response(grounded_context(),
              adapter: IdentityViolationAdapter
            )

    assert Enum.any?(errors, &(&1.code == :target_identity_violation))
  end
end
