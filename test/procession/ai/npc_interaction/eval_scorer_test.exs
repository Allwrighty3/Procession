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
end
