defmodule Procession.AI.NPCInteraction.RoleBoundaryExampleLoaderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.RoleBoundaryExampleLoader

  test "loads default role-boundary examples" do
    assert {:ok, examples} = RoleBoundaryExampleLoader.load_default()

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
    assert RoleBoundaryExampleLoader.load(nil) ==
             {:error, :invalid_role_boundary_example_path}
  end

  test "returns file read errors" do
    assert {:error, :enoent} =
             RoleBoundaryExampleLoader.load("priv/training/missing_role_boundary_examples.jsonl")
  end

  test "returns invalid JSONL line errors" do
    path = "tmp_invalid_role_boundary_examples.jsonl"

    File.write!(path, """
    {"id":"valid","message":"hello","target_id":"npc_tobin","response":"hi"}
    not valid json
    """)

    assert {:error, {:invalid_jsonl_line, 2, _reason}} = RoleBoundaryExampleLoader.load(path)

    File.rm!(path)
  end
end
