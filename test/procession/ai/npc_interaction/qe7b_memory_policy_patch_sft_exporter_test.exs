defmodule Procession.AI.NPCInteraction.QE7BMemoryPolicyPatchSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE7BMemoryPolicyPatchSFTExporter
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  @examples_path "priv/training/npc_interaction_qe7b_memory_policy_patch_examples.jsonl"

  test "exports QE7b memory policy patch SFT rows" do
    output_path = "tmp/training_exports/npc_interaction_qe7b_memory_policy_patch_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE7BMemoryPolicyPatchSFTExporter.export(output_path)
    assert {:ok, examples} = VoiceExpressionExampleLoader.load(@examples_path)

    assert summary.output_path == output_path
    assert summary.example_count == length(examples)
    assert summary.exported_count == length(examples)

    rows = read_jsonl!(output_path)

    assert length(rows) == length(examples)
    assert length(rows) == 20

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               String.starts_with?(row["id"], "qe7b_memory_policy_patch_") and
               is_binary(row["prompt"]) and
               is_binary(row["completion"]) and
               row["text"] == row["prompt"] <> "\n" <> row["completion"] and
               is_map(row["metadata"])
           end)

    File.rm!(output_path)
  end

  test "exports prompts with recent memory policy context" do
    output_path =
      "tmp/training_exports/npc_interaction_qe7b_memory_policy_patch_prompt_shape.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE7BMemoryPolicyPatchSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["prompt"] =~ "### Response Intent" and
               row["prompt"] =~ "### Expression Context" and
               row["prompt"] =~ "recent_memory" and
               row["prompt"] =~ "reference_policy" and
               row["prompt"] =~ "stance_effect" and
               row["prompt"] =~ "voice_profile" and
               row["prompt"] =~ "relationship_stance" and
               row["prompt"] =~ "conversational_move"
           end)

    ignore_row =
      Enum.find(rows, fn row ->
        row["id"] == "qe7b_memory_policy_patch_qe7b_corvin_irrelevant_bread_ignore"
      end)

    assert ignore_row
    assert ignore_row["prompt"] =~ "do_not_reference"
    assert ignore_row["prompt"] =~ "bought bread"
    assert ignore_row["completion"] == "Corvin."

    allude_row =
      Enum.find(rows, fn row ->
        row["id"] == "qe7b_memory_policy_patch_qe7b_bram_hives_again_may_allude"
      end)

    assert allude_row
    assert allude_row["prompt"] =~ "may_allude"
    assert allude_row["completion"] == "Depends. This about the hives again?"

    File.rm!(output_path)
  end

  test "marks exported rows as non-authoritative synthetic QE7b patch data" do
    output_path = "tmp/training_exports/npc_interaction_qe7b_memory_policy_patch_metadata.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE7BMemoryPolicyPatchSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["synthetic"] == true and
               row["metadata"]["source"] ==
                 "npc_interaction_qe7b_memory_policy_patch_example" and
               row["metadata"]["category"] == "npc_interaction_qe7b_memory_policy_patch" and
               is_map(row["metadata"]["intent"]) and
               is_map(row["metadata"]["voice_profile"]) and
               is_map(row["metadata"]["relationship_stance"]) and
               is_map(row["metadata"]["emotional_state"]) and
               is_map(row["metadata"]["delivery_style"]) and
               is_map(row["metadata"]["conversational_move"]) and
               is_map(row["metadata"]["recent_memory"])
           end)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE7BMemoryPolicyPatchSFTExporter.export(nil) ==
             {:error, :invalid_qe7b_memory_policy_patch_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
