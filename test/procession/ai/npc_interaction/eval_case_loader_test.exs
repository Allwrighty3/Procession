defmodule Procession.AI.NPCInteraction.EvalCaseLoaderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.EvalCaseLoader

  test "loads default NPC interaction eval cases" do
    assert {:ok, cases} = EvalCaseLoader.load_default()

    assert length(cases) == 5

    assert Enum.all?(cases, fn eval_case ->
             is_binary(eval_case["id"]) and
               is_binary(eval_case["target_id"]) and
               is_binary(eval_case["message"]) and
               is_list(eval_case["must_include_any"]) and
               is_list(eval_case["must_not_include"]) and
               is_boolean(eval_case["expected_unknown"]) and
               is_binary(eval_case["notes"])
           end)
  end

  test "returns an error for invalid paths" do
    assert EvalCaseLoader.load(nil) == {:error, :invalid_eval_case_path}
  end

  test "returns an error when the file does not exist" do
    assert {:error, :enoent} = EvalCaseLoader.load("priv/evals/missing_cases.jsonl")
  end

  test "returns line number for invalid JSONL" do
    path = Path.join(System.tmp_dir!(), "invalid_npc_eval_cases.jsonl")

    File.write!(path, """
    {"id":"valid"}
    not-json
    """)

    assert {:error, {:invalid_jsonl_line, 2, _reason}} = EvalCaseLoader.load(path)

    File.rm(path)
  end
end
