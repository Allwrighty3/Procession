defmodule Procession.AI.NPCInteraction.UnknownBoundaryExampleLoaderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.UnknownBoundaryExampleLoader

  test "loads default unknown-boundary examples" do
    assert {:ok, examples} = UnknownBoundaryExampleLoader.load_default()

    assert is_list(examples)
    assert length(examples) > 0

    assert Enum.all?(examples, fn example ->
             is_map(example) and
               is_binary(example["id"]) and
               is_binary(example["message"]) and
               is_binary(example["target_id"]) and
               is_binary(example["response"])
           end)
  end

  test "rejects invalid paths" do
    assert UnknownBoundaryExampleLoader.load(nil) ==
             {:error, :invalid_unknown_boundary_example_path}
  end

  test "returns file read errors" do
    assert {:error, :enoent} =
             UnknownBoundaryExampleLoader.load(
               "priv/training/missing_unknown_boundary_examples.jsonl"
             )
  end

  test "returns invalid JSONL line errors" do
    path = "tmp_invalid_unknown_boundary_examples.jsonl"

    File.write!(path, """
    {"id":"valid","message":"hello","target_id":"npc_tobin","response":"hi"}
    not valid json
    """)

    assert {:error, {:invalid_jsonl_line, 2, _reason}} = UnknownBoundaryExampleLoader.load(path)

    File.rm!(path)
  end
end
