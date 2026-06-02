defmodule Procession.AI.NPCInteraction.NaturalnessEvalCaseLoaderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.NaturalnessEvalCaseLoader

  test "loads default naturalness eval cases" do
    assert {:ok, cases} = NaturalnessEvalCaseLoader.load_default()

    assert is_list(cases)
    assert length(cases) > 0

    assert Enum.all?(cases, fn eval_case ->
             is_map(eval_case) and
               is_binary(eval_case["id"]) and
               is_binary(eval_case["response"])
           end)
  end

  test "rejects invalid paths" do
    assert NaturalnessEvalCaseLoader.load(nil) ==
             {:error, :invalid_naturalness_eval_case_path}
  end

  test "returns file read errors" do
    assert {:error, :enoent} =
             NaturalnessEvalCaseLoader.load("priv/evals/missing_naturalness_cases.jsonl")
  end

  test "returns invalid JSONL line errors" do
    path = "tmp_invalid_naturalness_cases.jsonl"

    File.write!(path, """
    {"id":"valid_case","response":"hello"}
    not valid json
    """)

    assert {:error, {:invalid_jsonl_line, 2, _reason}} =
             NaturalnessEvalCaseLoader.load(path)

    File.rm!(path)
  end
end
