defmodule Procession.AI.NPCInteraction.QE6RelationshipExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE6RelationshipExpressionSFTExporter
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  @examples_path "priv/training/npc_interaction_qe6_relationship_expression_examples.jsonl"

  test "exports QE6 relationship expression SFT rows" do
    output_path =
      "tmp/training_exports/npc_interaction_qe6_relationship_expression_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE6RelationshipExpressionSFTExporter.export(output_path)
    assert {:ok, examples} = VoiceExpressionExampleLoader.load(@examples_path)

    assert summary.output_path == output_path
    assert summary.example_count == length(examples)
    assert summary.exported_count == length(examples)

    rows = read_jsonl!(output_path)

    assert length(rows) == length(examples)

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               String.starts_with?(row["id"], "qe6_relationship_expression_") and
               is_binary(row["prompt"]) and
               is_binary(row["completion"]) and
               is_binary(row["text"]) and
               is_map(row["metadata"])
           end)

    assert Enum.all?(rows, fn row ->
             row["text"] == row["prompt"] <> "\n" <> row["completion"]
           end)

    File.rm!(output_path)
  end

  test "exports prompts with nested relationship expression context" do
    output_path =
      "tmp/training_exports/npc_interaction_qe6_relationship_expression_prompt_shape.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE6RelationshipExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["prompt"] =~ "### Expression Context" and
               row["prompt"] =~ "voice_profile" and
               row["prompt"] =~ "relationship_stance" and
               row["prompt"] =~ "listener" and
               row["prompt"] =~ "subject" and
               row["prompt"] =~ "emotional_state" and
               row["prompt"] =~ "delivery_style" and
               row["prompt"] =~ "conversational_move"
           end)

    assert Enum.any?(rows, fn row ->
             row["id"] == "qe6_relationship_expression_mira_tobin_not_brother_to_child" and
               row["prompt"] =~ "\"role\": \"child\"" and
               row["prompt"] =~ "\"attitude\": \"gentle\"" and
               row["completion"] == "No, dear. Tobin isn't my brother."
           end)

    File.rm!(output_path)
  end

  test "marks exported rows as non-authoritative QE6 relationship expression data" do
    output_path =
      "tmp/training_exports/npc_interaction_qe6_relationship_expression_metadata.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE6RelationshipExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["source"] ==
                 "npc_interaction_qe6_relationship_expression_example" and
               row["metadata"]["category"] == "npc_interaction_qe6_relationship_expression" and
               is_map(row["metadata"]["voice_profile"]) and
               is_map(row["metadata"]["relationship_stance"]) and
               is_map(row["metadata"]["relationship_stance"]["listener"]) and
               is_map(row["metadata"]["relationship_stance"]["subject"]) and
               is_map(row["metadata"]["emotional_state"]) and
               is_map(row["metadata"]["delivery_style"]) and
               is_map(row["metadata"]["conversational_move"])
           end)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE6RelationshipExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe6_relationship_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
