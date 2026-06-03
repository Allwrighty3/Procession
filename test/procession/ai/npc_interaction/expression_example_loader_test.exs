defmodule Procession.AI.NPCInteraction.ExpressionExampleLoaderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ExpressionExampleLoader

  test "loads default expression examples" do
    assert {:ok, examples} = ExpressionExampleLoader.load_default()

    assert is_list(examples)
    assert length(examples) >= 10

    assert Enum.all?(examples, fn example ->
             is_map(example) and
               is_binary(example["id"]) and
               is_binary(example["target_id"]) and
               is_binary(example["message"]) and
               is_binary(example["fallback_response"]) and
               is_binary(example["response"])
           end)
  end

  test "rejects invalid paths" do
    assert ExpressionExampleLoader.load(nil) ==
             {:error, :invalid_expression_example_path}
  end

  test "returns file read errors" do
    assert {:error, :enoent} =
             ExpressionExampleLoader.load("priv/training/missing_expression_examples.jsonl")
  end

  test "returns invalid JSONL line errors" do
    path = "tmp_invalid_expression_examples.jsonl"

    File.write!(path, """
    {"id":"valid","target_id":"npc_tobin","message":"hello","fallback_response":"hi","response":"hi"}
    not valid json
    """)

    assert {:error, {:invalid_jsonl_line, 2, _reason}} =
             ExpressionExampleLoader.load(path)

    File.rm!(path)
  end
end
