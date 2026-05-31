defmodule Procession.AI.NPCInteractionTest do
  use ExUnit.Case

  alias Procession.AI.NPCInteraction

  defmodule EchoAdapter do
    def generate(prompt, _opts), do: {:ok, prompt}
  end

  test "generate_response routes grounded context through the AI boundary" do
    context = %{
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
      active_entities: [],
      target_memories: [],
      message: "Who is Mira?"
    }

    assert {:ok, response} =
             NPCInteraction.generate_response(context, adapter: EchoAdapter)

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
end
