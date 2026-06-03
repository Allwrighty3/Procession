defmodule Procession.AI.NPCInteraction.ResponseTextValidatorTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ResponseTextValidator

  test "accepts grounded known entity response text" do
    intent = known_entity_intent()

    assert {:ok, "Mira is the innkeeper in Briar Village."} =
             ResponseTextValidator.validate(intent, "Mira is the innkeeper in Briar Village.")
  end

  test "rejects blank response text" do
    assert {:error, failures} = ResponseTextValidator.validate(known_entity_intent(), " ")

    assert Enum.any?(failures, fn failure ->
             failure.code == :blank_response_text
           end)
  end

  test "rejects prompt residue" do
    assert {:error, failures} =
             ResponseTextValidator.validate(known_entity_intent(), "### Response\nMira is here.")

    assert Enum.any?(failures, fn failure ->
             failure.code == :prompt_residue
           end)
  end

  test "rejects wrong speaker identity" do
    intent = self_identity_intent()

    assert {:error, failures} = ResponseTextValidator.validate(intent, "I'm Mira, the innkeeper.")

    assert Enum.any?(failures, fn failure ->
             failure.code == :wrong_speaker_identity
           end)
  end

  test "rejects forbidden role transfer" do
    intent = false_role_intent()

    assert {:error, failures} =
             ResponseTextValidator.validate(
               intent,
               "No, I don't run the inn. I'm Tobin, the innkeeper."
             )

    assert Enum.any?(failures, fn failure ->
             failure.code == :forbidden_invention and
               failure.forbidden_invention == "Tobin innkeeper role"
           end)
  end

  test "rejects unknown entity trait invention" do
    intent = unknown_entity_intent()

    assert {:error, failures} =
             ResponseTextValidator.validate(intent, "Elandra is a merchant at the crossroads.")

    assert Enum.any?(failures, fn failure ->
             failure.code == :unknown_trait_invention and failure.entity_name == "Elandra"
           end)
  end

  test "rejects current activity invention" do
    intent = current_activity_intent()

    assert {:error, failures} =
             ResponseTextValidator.validate(
               intent,
               "Mira is serving drinks right now at the inn."
             )

    assert Enum.any?(failures, fn failure ->
             failure.code == :forbidden_invention and
               failure.forbidden_invention == "Mira current activity"
           end)
  end

  test "returns input error for invalid arguments" do
    assert {:error, [%{code: :invalid_response_text_validation_input}]} =
             ResponseTextValidator.validate(nil, nil)
  end

  defp known_entity_intent do
    %{
      "speaker_id" => "npc_tobin",
      "target_id" => "npc_tobin",
      "dialogue_act" => "answer_known_entity",
      "response_goal" => "Tell the player Mira is the innkeeper associated with Briar Village.",
      "known_facts_used" => [
        %{"entity_id" => "npc_mira", "field" => "name", "value" => "Mira"},
        %{"entity_id" => "npc_mira", "field" => "role", "value" => "innkeeper"},
        %{"entity_id" => "npc_mira", "field" => "location", "value" => "Briar Village"}
      ],
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "Mira current activity",
        "Mira relationship to Tobin",
        "Tobin role transfer",
        "Tobin location transfer"
      ]
    }
  end

  defp self_identity_intent do
    %{
      "speaker_id" => "npc_tobin",
      "target_id" => "npc_tobin",
      "dialogue_act" => "answer_self_identity",
      "response_goal" => "Tell the player that the target NPC is Tobin.",
      "known_facts_used" => [
        %{"entity_id" => "npc_tobin", "field" => "name", "value" => "Tobin"},
        %{"entity_id" => "npc_tobin", "field" => "role", "value" => "merchant"},
        %{"entity_id" => "npc_tobin", "field" => "location", "value" => "crossroads"}
      ],
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "another NPC identity",
        "unknown relationships",
        "unknown current activity"
      ]
    }
  end

  defp false_role_intent do
    %{
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
  end

  defp unknown_entity_intent do
    %{
      "speaker_id" => "npc_tobin",
      "target_id" => "npc_tobin",
      "dialogue_act" => "express_uncertainty",
      "response_goal" => "Tell the player the target NPC does not know who Elandra is.",
      "known_facts_used" => [],
      "unknowns_acknowledged" => [
        %{"entity_name" => "Elandra", "reason" => "not present in known_entities"}
      ],
      "forbidden_inventions" => [
        "Elandra role",
        "Elandra location",
        "Elandra relationship",
        "Elandra current activity"
      ]
    }
  end

  defp current_activity_intent do
    %{
      "speaker_id" => "npc_tobin",
      "target_id" => "npc_tobin",
      "dialogue_act" => "express_uncertainty",
      "response_goal" =>
        "Tell the player the target NPC does not know what Mira is doing right now.",
      "known_facts_used" => [
        %{"entity_id" => "npc_mira", "field" => "name", "value" => "Mira"},
        %{"entity_id" => "npc_mira", "field" => "role", "value" => "innkeeper"},
        %{"entity_id" => "npc_mira", "field" => "location", "value" => "Briar Village"}
      ],
      "unknowns_acknowledged" => [
        %{
          "entity_name" => "Mira",
          "field" => "current_activity",
          "reason" => "current activity not present in grounded context"
        }
      ],
      "forbidden_inventions" => [
        "Mira current activity",
        "Mira implied activity from role",
        "Mira implied activity from location"
      ]
    }
  end
end
