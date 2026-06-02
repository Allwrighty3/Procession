defmodule Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoaderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader

  test "loads default contrastive naturalness eval cases" do
    assert {:ok, cases} = ContrastiveNaturalnessEvalCaseLoader.load_default()

    assert is_list(cases)
    assert length(cases) > 0

    assert Enum.all?(cases, fn eval_case ->
             is_map(eval_case) and
               is_binary(eval_case["id"]) and
               is_binary(eval_case["worse_response"]) and
               is_binary(eval_case["better_response"])
           end)
  end

  test "rejects invalid paths" do
    assert ContrastiveNaturalnessEvalCaseLoader.load(nil) ==
             {:error, :invalid_contrastive_naturalness_eval_case_path}
  end

  test "returns file read errors" do
    assert {:error, :enoent} =
             ContrastiveNaturalnessEvalCaseLoader.load(
               "priv/evals/missing_contrastive_naturalness_cases.jsonl"
             )
  end

  test "returns invalid JSONL line errors" do
    path = "tmp_invalid_contrastive_naturalness_cases.jsonl"

    File.write!(path, """
    {"id":"valid_case","worse_response":"bad","better_response":"good"}
    not valid json
    """)

    assert {:error, {:invalid_jsonl_line, 2, _reason}} =
             ContrastiveNaturalnessEvalCaseLoader.load(path)

    File.rm!(path)
  end
end
