defmodule Procession.AI.NPCInteraction.QE6DDisclosureRelationshipExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE6DDisclosureRelationshipExpressionSFTExporter
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  @examples_path "priv/training/npc_interaction_qe6d_relationship_expression_disclosure_patch_examples.jsonl"

  test "exports QE6d disclosure relationship expression SFT rows" do
    output_path = "tmp/training_exports/npc_interaction_qe6d_disclosure_relationship_expression_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE6DDisclosureRelationshipExpressionSFTExporter.export(output_path)
    assert {:ok, examples} = VoiceExpressionExampleLoader.load(@examples_path)

    assert summary.output_path == output_path
    assert summary.example_count == length(examples)
    assert summary.exported_count == length(examples)

    rows = read_jsonl!(output_path)

    assert length(rows) == length(examples)
    assert length(rows) == 19

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               String.starts_with?(row["id"], "qe6d_disclosure_relationship_expression_") and
               is_binary(row["prompt"]) and
               is_binary(row["completion"]) and
               row["text"] == row["prompt"] <> "\n" <> row["completion"] and
               is_map(row["metadata"])
           end)

    File.rm!(output_path)
  end

  test "exports disclosure-control prompt context" do
    output_path = "tmp/training_exports/npc_interaction_qe6d_disclosure_prompt_shape.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE6DDisclosureRelationshipExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["prompt"] =~ "### Response Intent" and
               row["prompt"] =~ "### Expression Context" and
               row["prompt"] =~ "voice_profile" and
               row["prompt"] =~ "relationship_stance" and
               row["prompt"] =~ "conversational_move"
           end)

    withhold_row =
      Enum.find(rows, fn row ->
        row["id"] == "qe6d_disclosure_relationship_expression_qe6d_nella_guarded_withhold"
      end)

    assert withhold_row
    assert withhold_row["prompt"] =~ "withhold_and_question"
    assert withhold_row["completion"] == "Who's asking?"

    name_only_row =
      Enum.find(rows, fn row ->
        row["id"] == "qe6d_disclosure_relationship_expression_qe6d_nella_name_only_neutral"
      end)

    assert name_only_row
    assert name_only_row["prompt"] =~ "name_only"
    assert name_only_row["completion"] == "Nella."

    File.rm!(output_path)
  end

  test "marks exported rows as non-authoritative synthetic QE6d disclosure data" do
    output_path = "tmp/training_exports/npc_interaction_qe6d_disclosure_metadata.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE6DDisclosureRelationshipExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["synthetic"] == true and
               row["metadata"]["source"] ==
                 "npc_interaction_qe6d_disclosure_relationship_expression_example" and
               row["metadata"]["category"] ==
                 "npc_interaction_qe6d_disclosure_relationship_expression" and
               is_map(row["metadata"]["intent"]) and
               is_map(row["metadata"]["voice_profile"]) and
               is_map(row["metadata"]["relationship_stance"]) and
               is_map(row["metadata"]["emotional_state"]) and
               is_map(row["metadata"]["delivery_style"]) and
               is_map(row["metadata"]["conversational_move"])
           end)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE6DDisclosureRelationshipExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe6d_disclosure_relationship_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
