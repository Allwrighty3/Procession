defmodule Procession.AI.NPCInteraction.QE6CRelationshipExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE6CRelationshipExpressionSFTExporter

  test "exports combined QE6c relationship expression SFT rows" do
    output_path = "tmp/training_exports/npc_interaction_qe6c_relationship_expression_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE6CRelationshipExpressionSFTExporter.export(output_path)

    assert summary.output_path == output_path
    assert summary.canonical_count == 24
    assert summary.synthetic_count == 23
    assert summary.exported_count == 47

    rows = read_jsonl!(output_path)

    assert length(rows) == 47

    assert Enum.any?(rows, fn row ->
             String.starts_with?(row["id"], "qe6b_relationship_expression_") and
               row["metadata"]["category"] == "npc_interaction_qe6b_relationship_expression"
           end)

    assert Enum.any?(rows, fn row ->
             String.starts_with?(row["id"], "qe6c_synthetic_relationship_expression_") and
               row["metadata"]["category"] ==
                 "npc_interaction_qe6c_synthetic_relationship_expression" and
               row["metadata"]["synthetic"] == true
           end)

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               is_binary(row["prompt"]) and
               is_binary(row["completion"]) and
               row["text"] == row["prompt"] <> "\n" <> row["completion"] and
               row["metadata"]["non_authoritative"] == true
           end)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE6CRelationshipExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe6c_relationship_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
