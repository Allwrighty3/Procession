defmodule Procession.AI.NPCInteraction.VoiceExpressionExampleLoaderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  test "loads default voice expression examples" do
    assert {:ok, examples} = VoiceExpressionExampleLoader.load_default()

    assert is_list(examples)
    assert length(examples) >= 12

    assert Enum.all?(examples, fn example ->
             is_map(example) and
               is_binary(example["id"]) and
               is_binary(example["target_id"]) and
               is_binary(example["message"]) and
               is_binary(example["fallback_response"]) and
               is_map(example["voice_profile"]) and
               is_map(example["relationship_stance"]) and
               is_binary(example["response"])
           end)
  end

  test "includes haughty Mira examples" do
    assert {:ok, examples} = VoiceExpressionExampleLoader.load_default()

    assert Enum.any?(examples, fn example ->
             example["id"] == "voice_mira_haughty_tobin_idiot" and
               example["voice_profile"]["tone"] == "haughty" and
               example["relationship_stance"]["attitude"] == "dismissive" and
               example["response"] == "Tobin? The idiot at the crossroads? Not a chance."
           end)
  end

  test "rejects invalid paths" do
    assert VoiceExpressionExampleLoader.load(nil) ==
             {:error, :invalid_voice_expression_example_path}
  end

  test "returns file read errors" do
    assert {:error, :enoent} =
             VoiceExpressionExampleLoader.load("priv/training/missing_voice_expression_examples.jsonl")
  end

  test "returns invalid JSONL line errors" do
    path = "tmp_invalid_voice_expression_examples.jsonl"

    File.write!(path, """
    {"id":"valid","target_id":"npc_tobin","message":"hello","fallback_response":"hi","voice_profile":{},"relationship_stance":{},"response":"hi"}
    not valid json
    """)

    assert {:error, {:invalid_jsonl_line, 2, _reason}} =
             VoiceExpressionExampleLoader.load(path)

    File.rm!(path)
  end
end
