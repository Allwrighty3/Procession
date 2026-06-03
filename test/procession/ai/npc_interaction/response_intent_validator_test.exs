defmodule Procession.AI.NPCInteraction.ResponseIntentValidatorTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ResponseIntentValidator

  test "validates a grounded known-entity response intent" do
    intent = %{
      "speaker_id" => "npc_tobin",
      "target_id" => "npc_tobin",
      "dialogue_act" => "answer_known_entity",
      "response_goal" => "Tell the player Mira keeps the inn in Briar Village.",
      "known_facts_used" => [
        %{"entity_id" => "npc_mira", "field" => "role", "value" => "innkeeper"},
        %{"entity_id" => "npc_mira", "field" => "location", "value" => "Briar Village"}
      ],
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "Mira current activity",
        "Mira relationship to Tobin",
        "Tobin innkeeper role"
      ]
    }

    assert {:ok, ^intent} = ResponseIntentValidator.validate(intent)
  end

  test "validates a natural uncertainty response intent" do
    intent = %{
      "speaker_id" => "npc_tobin",
      "target_id" => "npc_tobin",
      "dialogue_act" => "express_uncertainty",
      "response_goal" => "Tell the player Tobin has not heard of Elandra.",
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

    assert {:ok, ^intent} = ResponseIntentValidator.validate(intent)
  end

  test "rejects non-map input" do
    assert {:error, [%{code: :invalid_intent}]} = ResponseIntentValidator.validate(nil)
  end

  test "rejects missing required fields" do
    assert {:error, failures} = ResponseIntentValidator.validate(%{})

    assert Enum.any?(failures, fn failure ->
             failure.code == :missing_required_field and failure.field == "speaker_id"
           end)

    assert Enum.any?(failures, fn failure ->
             failure.code == :missing_required_field and failure.field == "dialogue_act"
           end)
  end

  test "rejects speaker and target mismatch" do
    intent =
      valid_intent(%{
        "speaker_id" => "npc_mira",
        "target_id" => "npc_tobin"
      })

    assert {:error, failures} = ResponseIntentValidator.validate(intent)

    assert Enum.any?(failures, fn failure ->
             failure.code == :speaker_target_mismatch
           end)
  end

  test "rejects unsupported dialogue acts" do
    intent = valid_intent(%{"dialogue_act" => "invent_lore_dump"})

    assert {:error, failures} = ResponseIntentValidator.validate(intent)

    assert Enum.any?(failures, fn failure ->
             failure.code == :unsupported_dialogue_act and
               failure.dialogue_act == "invent_lore_dump"
           end)
  end

  test "rejects invalid list fields" do
    intent =
      valid_intent(%{
        "known_facts_used" => "Mira is an innkeeper"
      })

    assert {:error, failures} = ResponseIntentValidator.validate(intent)

    assert Enum.any?(failures, fn failure ->
             failure.code == :invalid_list_field and failure.field == "known_facts_used"
           end)
  end

  test "rejects blank response goal" do
    intent = valid_intent(%{"response_goal" => " "})

    assert {:error, failures} = ResponseIntentValidator.validate(intent)

    assert Enum.any?(failures, fn failure ->
             failure.code == :blank_string_field and failure.field == "response_goal"
           end)
  end

  defp valid_intent(overrides) do
    Map.merge(
      %{
        "speaker_id" => "npc_tobin",
        "target_id" => "npc_tobin",
        "dialogue_act" => "answer_known_entity",
        "response_goal" => "Tell the player Mira keeps the inn in Briar Village.",
        "known_facts_used" => [],
        "unknowns_acknowledged" => [],
        "forbidden_inventions" => []
      },
      overrides
    )
  end
end
