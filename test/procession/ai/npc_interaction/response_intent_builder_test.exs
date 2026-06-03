defmodule Procession.AI.NPCInteraction.ResponseIntentBuilderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ResponseIntentBuilder

  test "builds self identity intent for target NPC" do
    assert {:ok, intent} = ResponseIntentBuilder.build(context(%{"message" => "Who are you?"}))

    assert intent["speaker_id"] == "npc_tobin"
    assert intent["target_id"] == "npc_tobin"
    assert intent["dialogue_act"] == "answer_self_identity"
    assert intent["response_goal"] =~ "Tobin"

    assert Enum.any?(intent["known_facts_used"], fn fact ->
             fact["field"] == "role" and fact["value"] == "merchant"
           end)
  end

  test "builds known entity intent without transferring target role" do
    assert {:ok, intent} = ResponseIntentBuilder.build(context(%{"message" => "Who is Mira?"}))

    assert intent["speaker_id"] == "npc_tobin"
    assert intent["target_id"] == "npc_tobin"
    assert intent["dialogue_act"] == "answer_known_entity"
    assert intent["response_goal"] =~ "Mira"
    assert intent["response_goal"] =~ "innkeeper"
    assert intent["response_goal"] =~ "Briar Village"

    assert Enum.any?(intent["known_facts_used"], fn fact ->
             fact["entity_id"] == "npc_mira" and
               fact["field"] == "role" and
               fact["value"] == "innkeeper"
           end)

    assert "Tobin role transfer" in intent["forbidden_inventions"]
  end

  test "builds unknown entity uncertainty intent" do
    assert {:ok, intent} = ResponseIntentBuilder.build(context(%{"message" => "Who is Elandra?"}))

    assert intent["speaker_id"] == "npc_tobin"
    assert intent["dialogue_act"] == "express_uncertainty"
    assert intent["response_goal"] =~ "Elandra"

    assert Enum.any?(intent["unknowns_acknowledged"], fn unknown ->
             unknown["entity_name"] == "Elandra" and
               unknown["reason"] == "not present in known_entities"
           end)

    assert "Elandra role" in intent["forbidden_inventions"]
    assert "Elandra location" in intent["forbidden_inventions"]
  end

  test "builds general uncertainty intent for unsupported question" do
    assert {:ok, intent} =
             ResponseIntentBuilder.build(context(%{"message" => "What is the weather?"}))

    assert intent["dialogue_act"] == "express_uncertainty"
    assert intent["response_goal"] =~ "does not know enough"

    assert Enum.any?(intent["unknowns_acknowledged"], fn unknown ->
             unknown["reason"] == "unsupported question pattern"
           end)
  end

  test "rejects invalid context" do
    assert ResponseIntentBuilder.build(nil) == {:error, :invalid_intent_context}
  end

  test "rejects context missing target" do
    bad_context =
      context()
      |> Map.delete("target")

    assert ResponseIntentBuilder.build(bad_context) ==
             {:error, {:missing_or_invalid_context_field, "target"}}
  end

  test "rejects context missing message" do
    bad_context =
      context()
      |> Map.delete("message")

    assert ResponseIntentBuilder.build(bad_context) ==
             {:error, {:missing_or_invalid_context_field, "message"}}
  end

  test "rejects context missing known entities" do
    bad_context =
      context()
      |> Map.delete("known_entities")

    assert ResponseIntentBuilder.build(bad_context) ==
             {:error, {:missing_or_invalid_context_field, "known_entities"}}
  end

  test "builds false role intent when target is asked about another NPC role" do
    assert {:ok, intent} =
             ResponseIntentBuilder.build(context(%{"message" => "Do you run the inn?"}))

    assert intent["speaker_id"] == "npc_tobin"
    assert intent["target_id"] == "npc_tobin"
    assert intent["dialogue_act"] == "reject_false_role"

    assert intent["response_goal"] =~ "Tobin is not the innkeeper"
    assert intent["response_goal"] =~ "Mira is"
    assert intent["response_goal"] =~ "Tobin is the merchant"

    assert Enum.any?(intent["known_facts_used"], fn fact ->
             fact["entity_id"] == "npc_tobin" and
               fact["field"] == "role" and
               fact["value"] == "merchant"
           end)

    assert Enum.any?(intent["known_facts_used"], fn fact ->
             fact["entity_id"] == "npc_mira" and
               fact["field"] == "role" and
               fact["value"] == "innkeeper"
           end)

    assert "Tobin innkeeper role" in intent["forbidden_inventions"]
    assert "Tobin role transfer" in intent["forbidden_inventions"]
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
