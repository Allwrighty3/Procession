defmodule Procession.AI.NPCInteraction.QE6DRelationshipExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE6DRelationshipExpressionSFTExporter

  test "exports combined QE6d relationship expression SFT rows" do
    output_path =
      "tmp/training_exports/npc_interaction_qe6d_relationship_expression_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE6DRelationshipExpressionSFTExporter.export(output_path)

    assert summary.output_path == output_path
    assert summary.qe6c_count == 47
    assert summary.disclosure_count == 19
    assert summary.exported_count == 66

    rows = read_jsonl!(output_path)

    assert length(rows) == 66

    assert Enum.any?(rows, fn row ->
             row["metadata"]["category"] == "npc_interaction_qe6b_relationship_expression"
           end)

    assert Enum.any?(rows, fn row ->
             row["metadata"]["category"] ==
               "npc_interaction_qe6c_synthetic_relationship_expression"
           end)

    assert Enum.any?(rows, fn row ->
             row["metadata"]["category"] ==
               "npc_interaction_qe6d_disclosure_relationship_expression"
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
    assert QE6DRelationshipExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe6d_relationship_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
