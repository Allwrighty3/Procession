defmodule Procession.AI.NPCInteraction.ResponseRealizerTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ResponseIntentBuilder
  alias Procession.AI.NPCInteraction.ResponseRealizer

  test "realizes self identity intent in first person" do
    assert {:ok, intent} = ResponseIntentBuilder.build(context(%{"message" => "Who are you?"}))

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response == "I'm Tobin, the merchant out by the crossroads."
  end

  test "realizes known entity intent without transferring roles" do
    assert {:ok, intent} = ResponseIntentBuilder.build(context(%{"message" => "Who is Mira?"}))

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response == "Mira is the innkeeper in Briar Village."
    refute response =~ "merchant"
    refute response =~ "crossroads"
  end

  test "realizes false role intent without transferring roles" do
    intent = %{
      "speaker_id" => "npc_tobin",
      "target_id" => "npc_tobin",
      "dialogue_act" => "reject_false_role",
      "response_goal" =>
        "Tell the player Tobin is not the innkeeper; Mira is. Tobin is the merchant associated with crossroads.",
      "known_facts_used" => [
        %{"entity_id" => "npc_tobin", "field" => "name", "value" => "Tobin"},
        %{"entity_id" => "npc_tobin", "field" => "role", "value" => "merchant"},
        %{"entity_id" => "npc_tobin", "field" => "location", "value" => "crossroads"},
        %{"entity_id" => "npc_mira", "field" => "name", "value" => "Mira"},
        %{"entity_id" => "npc_mira", "field" => "role", "value" => "innkeeper"},
        %{"entity_id" => "npc_mira", "field" => "location", "value" => "Briar Village"}
      ],
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "Tobin innkeeper role",
        "Tobin current activity",
        "Tobin role transfer"
      ]
    }

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response ==
             "No, Mira is the innkeeper. I'm Tobin, the merchant out by the crossroads."

    refute response =~ "I'm Mira"
    refute response =~ "I keep the inn"
  end

  test "realizes known location intent without claiming current presence" do
    intent = %{
      "speaker_id" => "npc_tobin",
      "target_id" => "npc_tobin",
      "dialogue_act" => "answer_known_location",
      "response_goal" =>
        "Tell the player Mira is associated with Briar Village, without inventing current activity.",
      "known_facts_used" => [
        %{"entity_id" => "npc_mira", "field" => "name", "value" => "Mira"},
        %{"entity_id" => "npc_mira", "field" => "location", "value" => "Briar Village"}
      ],
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "Mira current activity",
        "Mira relationship",
        "unlisted location details"
      ]
    }

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response ==
             "Mira is associated with Briar Village. I don't know where they are right now."

    refute response =~ "serving"
    refute response =~ "right now at"
  end

  test "realizes unknown entity intent without invented traits" do
    assert {:ok, intent} = ResponseIntentBuilder.build(context(%{"message" => "Who is Elandra?"}))

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response == "I don't know anyone named Elandra."
    refute response =~ "merchant"
    refute response =~ "innkeeper"
    refute response =~ "crossroads"
    refute response =~ "Briar Village"
  end

  test "realizes general uncertainty intent" do
    assert {:ok, intent} =
             ResponseIntentBuilder.build(context(%{"message" => "What is the weather?"}))

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response == "I don't know enough to answer that."
  end

  test "rejects invalid intent" do
    assert {:error, :invalid_response_intent} = ResponseRealizer.realize(nil)
  end

  test "returns validator errors for structurally invalid intent" do
    assert {:error, failures} = ResponseRealizer.realize(%{})

    assert Enum.any?(failures, fn failure ->
             failure.code == :missing_required_field
           end)
  end

  defp context(overrides) do
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
