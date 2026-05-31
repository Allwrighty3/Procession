defmodule Procession.AI.NPCInteraction.EvalScorerTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.EvalCaseLoader
  alias Procession.AI.NPCInteraction.EvalScorer

  defp eval_case(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "test_case",
        "target_id" => "npc_tobin",
        "message" => "Who is Mira?",
        "must_include" => [],
        "must_include_any" => ["Mira", "innkeeper", "Briar Village"],
        "must_not_include" => ["I am Mira", "I'm Mira"],
        "expected_unknown" => false,
        "notes" => "Test case."
      },
      overrides
    )
  end

  test "passes when response satisfies must_include_any and forbidden text is absent" do
    result =
      EvalScorer.score(
        eval_case(),
        "Mira is the innkeeper over in Briar Village."
      )

    assert result.passed
    assert result.failures == []
  end

  test "passes required text checks case-insensitively" do
    result =
      EvalScorer.score(
        eval_case(%{"must_include" => ["Mira"], "must_include_any" => []}),
        "mira keeps the inn."
      )

    assert result.passed
  end

  test "fails when required text is missing" do
    result =
      EvalScorer.score(
        eval_case(%{"must_include" => ["Tobin"], "must_include_any" => []}),
        "Mira keeps the inn."
      )

    refute result.passed

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :missing_required_text and failure.text == "Tobin"
           end)
  end

  test "fails when none of the must_include_any options are present" do
    result =
      EvalScorer.score(
        eval_case(%{"must_include_any" => ["merchant", "crossroads"]}),
        "Mira keeps the inn."
      )

    refute result.passed
    assert Enum.any?(result.failures, &(&1.code == :missing_any_required_text))
  end

  test "passes when must_include_any is empty" do
    result =
      EvalScorer.score(
        eval_case(%{"must_include" => ["Mira"], "must_include_any" => []}),
        "Mira keeps the inn."
      )

    assert result.passed
  end

  test "fails when forbidden text is present" do
    result =
      EvalScorer.score(
        eval_case(),
        "I am Mira, and I run the inn."
      )

    refute result.passed

    assert Enum.any?(result.failures, fn failure ->
             failure.code == :forbidden_text_present and failure.text == "I am Mira"
           end)
  end

  test "fails invalid scorer input" do
    result = EvalScorer.score(nil, %{text: "hello"})

    refute result.passed
    assert [%{code: :invalid_eval_input}] = result.failures
  end

  test "scores a loaded starter eval case" do
    assert {:ok, cases} = EvalCaseLoader.load_default()

    case = Enum.find(cases, &(&1["id"] == "known_entity_identity_tobin_about_mira"))

    result =
      EvalScorer.score(
        case,
        "Mira is the innkeeper over in Briar Village."
      )

    assert result.passed
  end

  test "scores multiple eval cases against provided responses" do
    cases = [
      eval_case(%{
        "id" => "case_pass",
        "must_include" => ["Mira"],
        "must_include_any" => [],
        "must_not_include" => ["I am Mira"]
      }),
      eval_case(%{
        "id" => "case_fail",
        "must_include" => ["Tobin"],
        "must_include_any" => [],
        "must_not_include" => []
      })
    ]

    responses = %{
      "case_pass" => "Mira keeps the inn.",
      "case_fail" => "Mira keeps the inn."
    }

    summary = EvalScorer.score_cases(cases, responses)

    assert summary.total == 2
    assert summary.passed == 1
    assert summary.failed == 1

    assert Enum.any?(summary.results, &(&1.id == "case_pass" and &1.passed))
    assert Enum.any?(summary.results, &(&1.id == "case_fail" and not &1.passed))
  end

  test "batch scoring treats missing responses as failures" do
    cases = [
      eval_case(%{
        "id" => "missing_response_case",
        "must_include" => ["Mira"],
        "must_include_any" => [],
        "must_not_include" => []
      })
    ]

    summary = EvalScorer.score_cases(cases, %{})

    assert summary.total == 1
    assert summary.passed == 0
    assert summary.failed == 1

    [result] = summary.results
    assert result.id == "missing_response_case"
    refute result.passed
    assert Enum.any?(result.failures, &(&1.code == :missing_required_text))
  end

  test "batch scoring rejects invalid input" do
    summary = EvalScorer.score_cases(nil, [])

    assert summary.total == 0
    assert summary.passed == 0
    assert summary.failed == 0

    [result] = summary.results
    refute result.passed
    assert Enum.any?(result.failures, &(&1.code == :invalid_eval_batch_input))
  end
end
