defmodule Procession.AI.NPCInteraction.QE7BMemoryExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE7BMemoryExpressionSFTExporter

  test "exports combined QE7b memory expression SFT rows" do
    output_path = "tmp/training_exports/npc_interaction_qe7b_memory_expression_sft_test.jsonl"

    File.mkdir_p!(Path.dirname(output_path))
    File.rm(output_path)

    assert {:ok, summary} = QE7BMemoryExpressionSFTExporter.export(output_path)

    assert summary.output_path == output_path
    assert summary.qe7_count == 13
    assert summary.patch_count == 20
    assert summary.exported_count == 33

    rows = read_jsonl!(output_path)

    assert length(rows) == 33

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
    assert QE7BMemoryExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe7b_memory_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
