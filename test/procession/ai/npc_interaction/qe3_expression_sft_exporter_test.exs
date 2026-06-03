defmodule Procession.AI.NPCInteraction.QE3ExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ExpressionExampleLoader
  alias Procession.AI.NPCInteraction.QE3ExpressionSFTExporter

  test "exports QE3 expression SFT rows" do
    output_path = "tmp_npc_interaction_qe3_expression_sft.jsonl"

    File.rm(output_path)

    assert {:ok, summary} = QE3ExpressionSFTExporter.export(output_path)
    assert {:ok, examples} = ExpressionExampleLoader.load_default()

    assert summary.output_path == output_path
    assert summary.example_count == length(examples)
    assert summary.exported_count == length(examples)

    rows = read_jsonl!(output_path)

    assert length(rows) == length(examples)

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               String.starts_with?(row["id"], "qe3_expression_") and
               is_binary(row["prompt"]) and
               is_binary(row["response"]) and
               is_binary(row["text"]) and
               is_map(row["metadata"])
           end)

    assert Enum.all?(rows, fn row ->
             row["text"] == row["prompt"] <> "\n" <> row["response"]
           end)

    File.rm!(output_path)
  end

  test "exports prompts that use response intent and deterministic fallback" do
    output_path = "tmp_npc_interaction_qe3_expression_sft_prompt_shape.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE3ExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["prompt"] =~ "### Task" and
               row["prompt"] =~ "### Response Intent" and
               row["prompt"] =~ "### Deterministic Fallback" and
               row["prompt"] =~ "### Final NPC Line"
           end)

    assert Enum.any?(rows, fn row ->
             row["metadata"]["message"] == "Who is Elandra?" and
               row["prompt"] =~ "I don't know anyone named Elandra." and
               row["response"] =~ "Elandra"
           end)

    File.rm!(output_path)
  end

  test "marks exported rows as non-authoritative expression data" do
    output_path = "tmp_npc_interaction_qe3_expression_sft_metadata.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE3ExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["source"] == "npc_interaction_expression_example" and
               row["metadata"]["category"] == "npc_interaction_expression"
           end)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE3ExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe3_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
