defmodule Procession.AI.NPCInteraction.QE7CMemoryExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE7CMemoryExpressionSFTExporter

  test "exports combined QE7c memory expression SFT rows" do
    output_path = "tmp/training_exports/npc_interaction_qe7c_memory_expression_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE7CMemoryExpressionSFTExporter.export(output_path)

    assert summary.output_path == output_path
    assert summary.qe6d_count == 66
    assert summary.qe7b_count == 33
    assert summary.exported_count == 99

    rows = read_jsonl!(output_path)

    assert length(rows) == 99

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

    assert Enum.any?(rows, fn row ->
             row["metadata"]["category"] == "npc_interaction_qe7_memory_expression"
           end)

    assert Enum.any?(rows, fn row ->
             row["metadata"]["category"] == "npc_interaction_qe7b_memory_policy_patch"
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
    assert QE7CMemoryExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe7c_memory_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
