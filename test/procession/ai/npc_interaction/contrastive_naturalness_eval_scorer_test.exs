defmodule Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalScorerTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalScorer

  test "passes a valid contrastive naturalness eval case" do
    eval_case = %{
      "id" => "prefer_conversational_known_entity",
      "category" => "contrastive_naturalness",
      "worse_response" => "Mira is the innkeeper in Briar Village.",
      "better_response" =>
        "Mira? She keeps the inn over in Briar Village. Good woman, knows most folks passing through.",
      "preference_reasons" => [
        "better response is grounded",
        "better response sounds conversational"
      ]
    }

    assert %{passed: true, failures: []} =
             ContrastiveNaturalnessEvalScorer.score(eval_case)
  end

  test "fails invalid eval input" do
    result = ContrastiveNaturalnessEvalScorer.score(nil)

    refute result.passed
    assert [%{code: :invalid_eval_input}] = result.failures
  end

  test "fails missing required response fields" do
    result =
      ContrastiveNaturalnessEvalScorer.score(%{
        "id" => "missing_fields",
        "preference_reasons" => ["better response answers the question"]
      })

    refute result.passed

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :missing_required_field and failure.field == "worse_response"
           end)

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :missing_required_field and failure.field == "better_response"
           end)
  end

  test "fails blank required string fields" do
    result =
      ContrastiveNaturalnessEvalScorer.score(%{
        "id" => " ",
        "worse_response" => "Bad.",
        "better_response" => "Better.",
        "preference_reasons" => ["better response is clearer"]
      })

    refute result.passed

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :blank_required_field and failure.field == "id"
           end)
  end

  test "fails when worse and better responses are the same" do
    result =
      ContrastiveNaturalnessEvalScorer.score(%{
        "id" => "same_responses",
        "worse_response" => "Mira is the innkeeper in Briar Village.",
        "better_response" => "Mira is the innkeeper in Briar Village.",
        "preference_reasons" => ["better response should differ"]
      })

    refute result.passed

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :responses_do_not_differ
           end)
  end

  test "fails when preference reasons are missing" do
    result =
      ContrastiveNaturalnessEvalScorer.score(%{
        "id" => "missing_reasons",
        "worse_response" => "Mira is the innkeeper in Briar Village.",
        "better_response" => "Mira? She keeps the inn over in Briar Village."
      })

    refute result.passed

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :missing_preference_reasons
           end)
  end

  test "scores loaded default contrastive naturalness cases" do
    assert {:ok, cases} = ContrastiveNaturalnessEvalCaseLoader.load_default()

    summary = ContrastiveNaturalnessEvalScorer.score_cases(cases)

    assert summary.total == length(cases)
    assert summary.total > 0
    assert summary.failed == 0
    assert summary.passed == summary.total
    assert length(summary.results) == summary.total
  end

  test "fails invalid batch input" do
    summary = ContrastiveNaturalnessEvalScorer.score_cases(nil)

    assert summary.total == 0
    assert summary.failed == 0

    assert [
             %{
               id: nil,
               passed: false,
               failures: [%{code: :invalid_eval_batch_input}]
             }
           ] = summary.results
  end
end
