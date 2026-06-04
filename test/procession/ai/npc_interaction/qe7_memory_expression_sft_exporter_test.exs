defmodule Procession.AI.NPCInteraction.QE7MemoryExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE7MemoryExpressionSFTExporter
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  @examples_path "priv/training/npc_interaction_qe7_memory_expression_examples.jsonl"

  test "exports QE7 memory expression SFT rows" do
    output_path = "tmp/training_exports/npc_interaction_qe7_memory_expression_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE7MemoryExpressionSFTExporter.export(output_path)
    assert {:ok, examples} = VoiceExpressionExampleLoader.load(@examples_path)

    assert summary.output_path == output_path
    assert summary.example_count == length(examples)
    assert summary.exported_count == length(examples)

    rows = read_jsonl!(output_path)

    assert length(rows) == length(examples)
    assert length(rows) == 13

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               String.starts_with?(row["id"], "qe7_memory_expression_") and
               is_binary(row["prompt"]) and
               is_binary(row["completion"]) and
               row["text"] == row["prompt"] <> "\n" <> row["completion"] and
               is_map(row["metadata"])
           end)

    File.rm!(output_path)
  end

  test "exports prompts with recent memory expression context" do
    output_path = "tmp/training_exports/npc_interaction_qe7_memory_expression_prompt_shape.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE7MemoryExpressionSFTExporter.export(output_path)

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

    tone_only_row =
      Enum.find(rows, fn row ->
        row["id"] == "qe7_memory_expression_qe7_mira_tobin_helped_inn_warm_no_reference"
      end)

    assert tone_only_row
    assert tone_only_row["prompt"] =~ "do_not_reference"
    assert tone_only_row["completion"] == "No, dear. Tobin isn't family."

    allude_row =
      Enum.find(rows, fn row ->
        row["id"] == "qe7_memory_expression_qe7_mira_tobin_repeated_questions_impatient_allude"
      end)

    assert allude_row
    assert allude_row["prompt"] =~ "may_allude"
    assert allude_row["completion"] == "No. Still not family."

    File.rm!(output_path)
  end

  test "marks exported rows as non-authoritative synthetic QE7 memory data" do
    output_path = "tmp/training_exports/npc_interaction_qe7_memory_expression_metadata.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE7MemoryExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["synthetic"] == true and
               row["metadata"]["source"] ==
                 "npc_interaction_qe7_memory_expression_example" and
               row["metadata"]["category"] == "npc_interaction_qe7_memory_expression" and
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
    assert QE7MemoryExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe7_memory_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
