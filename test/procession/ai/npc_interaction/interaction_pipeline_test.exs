defmodule Procession.AI.NPCInteraction.InteractionPipelineTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.InteractionPipeline

  test "responds to known entity question with grounded realized text" do
    assert {:ok, result} =
             InteractionPipeline.respond(context(%{"message" => "Who is Mira?"}))

    assert result.intent["dialogue_act"] == "answer_known_entity"
    assert result.response == "Mira is the innkeeper in Briar Village."
  end

  test "responds to self identity question in first person" do
    assert {:ok, result} =
             InteractionPipeline.respond(context(%{"message" => "Who are you?"}))

    assert result.intent["dialogue_act"] == "answer_self_identity"
    assert result.response == "I'm Tobin, the merchant out by the crossroads."
  end

  test "responds to unknown entity question with uncertainty" do
    assert {:ok, result} =
             InteractionPipeline.respond(context(%{"message" => "Who is Elandra?"}))

    assert result.intent["dialogue_act"] == "express_uncertainty"
    assert result.response == "I don't know anyone named Elandra."
  end

  test "does not transfer known roles into unknown entity response" do
    assert {:ok, result} =
             InteractionPipeline.respond(context(%{"message" => "Who is Elandra?"}))

    refute result.response =~ "merchant"
    refute result.response =~ "innkeeper"
    refute result.response =~ "crossroads"
    refute result.response =~ "Briar Village"
  end

  test "returns errors from invalid context" do
    assert InteractionPipeline.respond(nil) == {:error, :invalid_interaction_context}
  end

  test "returns builder errors for incomplete context" do
    bad_context =
      context()
      |> Map.delete("target")

    assert InteractionPipeline.respond(bad_context) ==
             {:error, {:missing_or_invalid_context_field, "target"}}
  end

  defp context(overrides \\ %{}) do
    Map.merge(
      %{
        "known_entities" => [
          %{
            "id" => "npc_tobin",
            "name" => "Tobin",
            "type" => "npc",
            "role" => "merchant",
            "location" => "crossroads"
          },
          %{
            "id" => "npc_mira",
            "name" => "Mira",
            "type" => "npc",
            "role" => "innkeeper",
            "location" => "Briar Village"
          }
        ],
        "message" => "Who is Mira?",
        "target" => %{
          "id" => "npc_tobin",
          "name" => "Tobin",
          "type" => "npc",
          "role" => "merchant",
          "location" => "crossroads"
        }
      },
      overrides
    )
  end
end
