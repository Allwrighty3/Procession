defmodule Procession.AI.NPCInteraction.QE6CSyntheticRelationshipExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE6CSyntheticRelationshipExpressionSFTExporter
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  @examples_path "priv/training/npc_interaction_qe6c_relationship_expression_synthetic_examples.jsonl"

  test "exports QE6c synthetic relationship expression SFT rows" do
    output_path = "tmp/training_exports/npc_interaction_qe6c_synthetic_relationship_expression_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE6CSyntheticRelationshipExpressionSFTExporter.export(output_path)
    assert {:ok, examples} = VoiceExpressionExampleLoader.load(@examples_path)

    assert summary.output_path == output_path
    assert summary.example_count == length(examples)
    assert summary.exported_count == length(examples)

    rows = read_jsonl!(output_path)

    assert length(rows) == length(examples)
    assert length(rows) == 23

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               String.starts_with?(row["id"], "qe6c_synthetic_relationship_expression_") and
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

  test "exports prompts from embedded synthetic intent and fallback" do
    output_path = "tmp/training_exports/npc_interaction_qe6c_synthetic_prompt_shape.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE6CSyntheticRelationshipExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["prompt"] =~ "### Response Intent" and
               row["prompt"] =~ "### Expression Context" and
               row["prompt"] =~ "### Deterministic Fallback" and
               row["prompt"] =~ "voice_profile" and
               row["prompt"] =~ "relationship_stance" and
               row["prompt"] =~ "listener" and
               row["prompt"] =~ "subject" and
               row["prompt"] =~ "emotional_state" and
               row["prompt"] =~ "delivery_style" and
               row["prompt"] =~ "conversational_move"
           end)

    john_row =
      Enum.find(rows, fn row ->
        row["id"] == "qe6c_synthetic_relationship_expression_qe6c_john_blacksmith_despondent_friend"
      end)

    assert john_row
    assert john_row["prompt"] =~ "John"
    assert john_row["prompt"] =~ "blacksmith"
    assert john_row["prompt"] =~ "despondent"
    assert john_row["completion"] ==
             "John. I work the forge in Greyford. Some days that sounds heavier than it should."

    File.rm!(output_path)
  end

  test "marks exported rows as non-authoritative synthetic QE6c data" do
    output_path = "tmp/training_exports/npc_interaction_qe6c_synthetic_metadata.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, _summary} = QE6CSyntheticRelationshipExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["synthetic"] == true and
               row["metadata"]["source"] ==
                 "npc_interaction_qe6c_synthetic_relationship_expression_example" and
               row["metadata"]["category"] ==
                 "npc_interaction_qe6c_synthetic_relationship_expression" and
               is_map(row["metadata"]["intent"]) and
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
    assert QE6CSyntheticRelationshipExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe6c_synthetic_relationship_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
