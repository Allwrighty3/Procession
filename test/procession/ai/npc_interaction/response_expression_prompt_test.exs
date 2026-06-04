defmodule Procession.AI.NPCInteraction.ResponseExpressionPromptTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ResponseExpressionPrompt

  test "renders expression prompt from valid intent and fallback" do
    intent = known_entity_intent()
    fallback = "Mira is the innkeeper in Briar Village."

    assert {:ok, prompt} = ResponseExpressionPrompt.render(intent, fallback)

    assert prompt =~ "### Task"
    assert prompt =~ "Rewrite the fallback NPC line"
    assert prompt =~ "### Hard Rules"
    assert prompt =~ "Return only the final NPC line."
    assert prompt =~ "Do not add objective world facts."
    assert prompt =~ "Do not change speaker identity."
    assert prompt =~ "If the fallback expresses uncertainty, preserve that uncertainty."
    assert prompt =~ "### Response Intent"
    assert prompt =~ "\"dialogue_act\": \"answer_known_entity\""
    assert prompt =~ "\"response_goal\""
    assert prompt =~ "Mira is the innkeeper in Briar Village."
    assert prompt =~ "### Final NPC Line"
    assert prompt =~ "### Expression Context"
    assert prompt =~ "may_use_subjective_opinion"
    assert prompt =~ "may_omit_nonessential_known_facts"
    assert prompt =~ "must_not_add_objective_world_facts"
    assert prompt =~ "emotional_state"
    assert prompt =~ "delivery_style"
    assert prompt =~ "conversational_move"
    assert prompt =~ "may_use_follow_up_questions"
    assert prompt =~ "may_use_short_answers"
  end

  test "includes forbidden inventions in rendered prompt" do
    intent = unknown_entity_intent()
    fallback = "I don't know anyone named Elandra."

    assert {:ok, prompt} = ResponseExpressionPrompt.render(intent, fallback)

    assert prompt =~ "Elandra role"
    assert prompt =~ "Elandra location"
    assert prompt =~ "Elandra relationship"
    assert prompt =~ "Elandra current activity"
  end

  test "rejects invalid intent" do
    assert {:error, failures} = ResponseExpressionPrompt.render(%{}, "Fallback text.")

    assert Enum.any?(failures, fn failure ->
             failure.code == :missing_required_field
           end)
  end

  test "rejects invalid input" do
    assert ResponseExpressionPrompt.render(nil, nil) == {:error, :invalid_expression_prompt_input}
  end

  test "renders optional voice profile relationship stance and emotional state" do
    intent = known_entity_intent()
    fallback = "Mira is the innkeeper in Briar Village."

    assert {:ok, prompt} =
             ResponseExpressionPrompt.render(
               intent,
               fallback,
               voice_profile: %{
                 "tone" => "haughty",
                 "warmth" => "low",
                 "bluntness" => "high"
               },
               relationship_stance: %{
                 "toward" => "npc_tobin",
                 "attitude" => "dismissive",
                 "trust" => "low"
               },
               emotional_state: %{
                 "mood" => "irritated",
                 "intensity" => "high",
                 "restraint" => "medium"
               }
             )

    assert prompt =~ "\"tone\": \"haughty\""
    assert prompt =~ "\"warmth\": \"low\""
    assert prompt =~ "\"bluntness\": \"high\""
    assert prompt =~ "\"attitude\": \"dismissive\""
    assert prompt =~ "\"trust\": \"low\""
    assert prompt =~ "\"mood\": \"irritated\""
    assert prompt =~ "\"intensity\": \"high\""
    assert prompt =~ "\"restraint\": \"medium\""
  end

  test "renders optional delivery style and conversational move" do
    intent = known_entity_intent()
    fallback = "Mira is the innkeeper in Briar Village."

    assert {:ok, prompt} =
             ResponseExpressionPrompt.render(
               intent,
               fallback,
               delivery_style: %{
                 "shape" => "terse",
                 "pace" => "quick",
                 "detail_level" => "minimal"
               },
               conversational_move: %{
                 "move" => "ask_followup",
                 "question_allowed" => true
               }
             )

    assert prompt =~ "\"shape\": \"terse\""
    assert prompt =~ "\"pace\": \"quick\""
    assert prompt =~ "\"detail_level\": \"minimal\""
    assert prompt =~ "\"move\": \"ask_followup\""
    assert prompt =~ "\"question_allowed\": true"
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
end
