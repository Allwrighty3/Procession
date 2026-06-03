defmodule Procession.AI.NPCInteraction.ResponseExpressionPipelineTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ResponseExpressionPipeline

  defmodule SafeAdapter do
    def generate(_prompt, _opts) do
      {:ok, "Mira keeps the inn in Briar Village."}
    end
  end

  defmodule UnsafeAdapter do
    def generate(_prompt, _opts) do
      {:ok, "Elandra is a merchant at the crossroads."}
    end
  end

  defmodule ErrorAdapter do
    def generate(_prompt, _opts) do
      {:error, :adapter_failed}
    end
  end

  defmodule NonStringAdapter do
    def generate(_prompt, _opts) do
      {:ok, %{text: "Mira keeps the inn."}}
    end
  end

  defmodule RamblySafeAdapter do
    def generate(_prompt, _opts) do
      {:ok, "Mira keeps the inn in Briar Village.\n### Response\nMira is still talking."}
    end
  end

  test "uses valid expression candidate" do
    fallback = "Mira is the innkeeper in Briar Village."

    assert {:ok, result} =
             ResponseExpressionPipeline.express(
               known_entity_intent(),
               fallback,
               adapter: SafeAdapter
             )

    assert result.response_source == :expression_candidate
    assert result.response == "Mira keeps the inn in Briar Village."
    assert result.fallback_response == fallback
    assert result.candidate_response == "Mira keeps the inn in Briar Village."
    assert result.validation_failures == []
    assert result.adapter_error == nil
    assert result.prompt =~ "### Final NPC Line"
  end

  test "falls back when expression candidate violates intent" do
    fallback = "I don't know anyone named Elandra."

    assert {:ok, result} =
             ResponseExpressionPipeline.express(
               unknown_entity_intent(),
               fallback,
               adapter: UnsafeAdapter
             )

    assert result.response_source == :deterministic
    assert result.response == fallback
    assert result.fallback_response == fallback
    assert result.candidate_response == "Elandra is a merchant at the crossroads."

    assert Enum.any?(result.validation_failures, fn failure ->
             failure.code == :unknown_trait_invention
           end)

    assert result.adapter_error == nil
  end

  test "falls back when expression adapter returns an error" do
    fallback = "Mira is the innkeeper in Briar Village."

    assert {:ok, result} =
             ResponseExpressionPipeline.express(
               known_entity_intent(),
               fallback,
               adapter: ErrorAdapter
             )

    assert result.response_source == :deterministic
    assert result.response == fallback
    assert result.fallback_response == fallback
    assert result.candidate_response == nil
    assert result.validation_failures == []
    assert result.adapter_error == :adapter_failed
  end

  test "falls back when expression adapter returns non-string candidate" do
    fallback = "Mira is the innkeeper in Briar Village."

    assert {:ok, result} =
             ResponseExpressionPipeline.express(
               known_entity_intent(),
               fallback,
               adapter: NonStringAdapter
             )

    assert result.response_source == :deterministic
    assert result.response == fallback
    assert result.fallback_response == fallback
    assert result.candidate_response == "%{text: \"Mira keeps the inn.\"}"

    assert Enum.any?(result.validation_failures, fn failure ->
             failure.code == :invalid_expression_candidate
           end)
  end

  test "cleans expression candidate before validation" do
    fallback = "Mira is the innkeeper in Briar Village."

    assert {:ok, result} =
             ResponseExpressionPipeline.express(
               known_entity_intent(),
               fallback,
               adapter: RamblySafeAdapter
             )

    assert result.response_source == :expression_candidate
    assert result.response == "Mira keeps the inn in Briar Village."
    assert result.candidate_response == "Mira keeps the inn in Briar Village."
    assert result.validation_failures == []
  end

  test "rejects invalid expression pipeline input" do
    assert ResponseExpressionPipeline.express(nil, nil) ==
             {:error, :invalid_expression_pipeline_input}
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
