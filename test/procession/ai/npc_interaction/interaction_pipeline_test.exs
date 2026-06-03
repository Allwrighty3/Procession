defmodule Procession.AI.NPCInteraction.InteractionPipelineTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.InteractionPipeline

  defmodule SafeExpressionAdapter do
    def generate(_prompt, _opts) do
      {:ok, "Mira keeps the inn in Briar Village."}
    end
  end

  defmodule UnsafeExpressionAdapter do
    def generate(_prompt, _opts) do
      {:ok, "Elandra is a merchant at the crossroads."}
    end
  end

  test "responds to known entity question with grounded realized text" do
    assert {:ok, result} = InteractionPipeline.respond(context(%{"message" => "Who is Mira?"}))

    assert result.intent["dialogue_act"] == "answer_known_entity"
    assert result.response == "Mira is the innkeeper in Briar Village."
  end

  test "responds to self identity question in first person" do
    assert {:ok, result} = InteractionPipeline.respond(context(%{"message" => "Who are you?"}))

    assert result.intent["dialogue_act"] == "answer_self_identity"
    assert result.response == "I'm Tobin, the merchant out by the crossroads."
  end

  test "responds to unknown entity question with uncertainty" do
    assert {:ok, result} = InteractionPipeline.respond(context(%{"message" => "Who is Elandra?"}))

    assert result.intent["dialogue_act"] == "express_uncertainty"
    assert result.response == "I don't know anyone named Elandra."
  end

  test "does not transfer known roles into unknown entity response" do
    assert {:ok, result} = InteractionPipeline.respond(context(%{"message" => "Who is Elandra?"}))

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

  test "uses deterministic response when no candidate response is provided" do
    assert {:ok, result} = InteractionPipeline.respond(context(%{"message" => "Who is Mira?"}))

    assert result.response_source == :deterministic
    assert result.response == "Mira is the innkeeper in Briar Village."
    assert result.fallback_response == "Mira is the innkeeper in Briar Village."
    assert result.validation_failures == []
  end

  test "uses valid candidate response instead of deterministic fallback" do
    assert {:ok, result} =
             InteractionPipeline.respond(
               context(%{"message" => "Who is Mira?"}),
               candidate_response: "Mira keeps the inn in Briar Village."
             )

    assert result.response_source == :candidate
    assert result.response == "Mira keeps the inn in Briar Village."
    assert result.fallback_response == "Mira is the innkeeper in Briar Village."
    assert result.validation_failures == []
  end

  test "falls back when candidate response violates intent" do
    assert {:ok, result} =
             InteractionPipeline.respond(
               context(%{"message" => "Who is Elandra?"}),
               candidate_response: "Elandra is a merchant at the crossroads."
             )

    assert result.response_source == :deterministic
    assert result.response == "I don't know anyone named Elandra."
    assert result.fallback_response == "I don't know anyone named Elandra."

    assert Enum.any?(result.validation_failures, fn failure ->
             failure.code == :unknown_trait_invention
           end)
  end

  test "falls back when candidate response claims wrong speaker identity" do
    assert {:ok, result} =
             InteractionPipeline.respond(
               context(%{"message" => "Who are you?"}),
               candidate_response: "I'm Mira, the innkeeper."
             )

    assert result.response_source == :deterministic
    assert result.response == "I'm Tobin, the merchant out by the crossroads."

    assert Enum.any?(result.validation_failures, fn failure ->
             failure.code == :wrong_speaker_identity
           end)
  end

  test "falls back when candidate response is not a string" do
    assert {:ok, result} =
             InteractionPipeline.respond(
               context(%{"message" => "Who is Mira?"}),
               candidate_response: %{text: "Mira keeps the inn."}
             )

    assert result.response_source == :deterministic
    assert result.response == "Mira is the innkeeper in Briar Village."

    assert Enum.any?(result.validation_failures, fn failure ->
             failure.code == :invalid_candidate_response
           end)
  end

  test "uses valid expression adapter response when provided" do
    assert {:ok, result} =
             InteractionPipeline.respond(
               context(%{"message" => "Who is Mira?"}),
               expression_adapter: SafeExpressionAdapter
             )

    assert result.response_source == :expression_candidate
    assert result.response == "Mira keeps the inn in Briar Village."
    assert result.fallback_response == "Mira is the innkeeper in Briar Village."
    assert result.validation_failures == []
    assert result.expression_prompt =~ "### Final NPC Line"
    assert result.expression_candidate_response == "Mira keeps the inn in Briar Village."
    assert result.expression_adapter_error == nil
  end

  test "falls back when expression adapter response violates intent" do
    assert {:ok, result} =
             InteractionPipeline.respond(
               context(%{"message" => "Who is Elandra?"}),
               expression_adapter: UnsafeExpressionAdapter
             )

    assert result.response_source == :deterministic
    assert result.response == "I don't know anyone named Elandra."
    assert result.fallback_response == "I don't know anyone named Elandra."
    assert result.expression_candidate_response == "Elandra is a merchant at the crossroads."

    assert Enum.any?(result.validation_failures, fn failure ->
             failure.code == :unknown_trait_invention
           end)
  end

  test "candidate response takes precedence over expression adapter" do
    assert {:ok, result} =
             InteractionPipeline.respond(
               context(%{"message" => "Who is Mira?"}),
               candidate_response: "Mira keeps the inn in Briar Village.",
               expression_adapter: UnsafeExpressionAdapter
             )

    assert result.response_source == :candidate
    assert result.response == "Mira keeps the inn in Briar Village."
    assert result.expression_prompt == nil
    assert result.expression_candidate_response == nil
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
