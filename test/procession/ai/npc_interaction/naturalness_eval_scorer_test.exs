defmodule Procession.AI.NPCInteraction.NaturalnessEvalScorerTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.NaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.NaturalnessEvalScorer

  test "passes a natural conversational response that satisfies the case" do
    eval_case = %{
      "id" => "known_fact_can_have_light_voice",
      "response" =>
        "Mira? She keeps the inn over in Briar Village. Good woman, knows most folks passing through.",
      "must_include" => [],
      "must_include_any" => ["Mira", "inn", "Briar Village"],
      "must_not_include" => ["###", "Explanation", "I am Mira"]
    }

    assert %{passed: true, failures: []} = NaturalnessEvalScorer.score(eval_case)
  end

  test "fails when forbidden JSON residue is present" do
    eval_case = %{
      "id" => "no_json_or_prompt_residue",
      "response" => ~s({"response":"Mira is the innkeeper in Briar Village."}),
      "must_include" => [],
      "must_include_any" => [],
      "must_not_include" => ["{", "}", "response"]
    }

    result = NaturalnessEvalScorer.score(eval_case)

    refute result.passed

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :forbidden_text_present and failure.text == "{"
           end)
  end

  test "fails when no allowed uncertainty phrase is present" do
    eval_case = %{
      "id" => "uncertainty_can_be_conversational",
      "response" => "Mira keeps the inn in Briar Village.",
      "must_include" => [],
      "must_include_any" => ["couldn't tell you", "don't know", "do not know", "not sure"],
      "must_not_include" => ["as an AI"]
    }

    result = NaturalnessEvalScorer.score(eval_case)

    refute result.passed

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :missing_any_required_text
           end)
  end

  test "fails invalid eval input" do
    result = NaturalnessEvalScorer.score(nil)

    refute result.passed

    assert [%{code: :invalid_eval_input}] = result.failures
  end

  test "fails eval case without response" do
    result = NaturalnessEvalScorer.score(%{"id" => "missing_response"})

    refute result.passed

    assert [%{code: :missing_response}] = result.failures
  end

  test "scores loaded default naturalness cases" do
    assert {:ok, cases} = NaturalnessEvalCaseLoader.load_default()

    summary = NaturalnessEvalScorer.score_cases(cases)

    assert summary.total == length(cases)
    assert summary.total > 0
    assert is_integer(summary.passed)
    assert is_integer(summary.failed)
    assert length(summary.results) == summary.total
  end

  test "fails invalid batch input" do
    summary = NaturalnessEvalScorer.score_cases(nil)

    assert summary.total == 0
    assert summary.failed == 0

    assert [%{id: nil, passed: false, failures: [%{code: :invalid_eval_batch_input}]}] =
             summary.results
  end
end
