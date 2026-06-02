defmodule Procession.AI.NPCInteraction.ContrastiveNaturalnessTrainingExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessTrainingExporter

  test "exports contrastive naturalness cases to preference-style JSONL rows" do
    output_path = "tmp_contrastive_naturalness_export.jsonl"

    File.rm(output_path)

    assert {:ok, summary} =
             ContrastiveNaturalnessTrainingExporter.export(output_path)

    assert summary.output_path == output_path
    assert summary.exported_count > 0

    assert {:ok, cases} = ContrastiveNaturalnessEvalCaseLoader.load_default()
    assert summary.exported_count == length(cases)

    rows =
      output_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert length(rows) == length(cases)

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               is_binary(row["prompt"]) and
               is_binary(row["chosen"]) and
               is_binary(row["rejected"]) and
               row["chosen"] != row["rejected"] and
               row["metadata"]["non_authoritative"] == true and
               row["metadata"]["source"] == "contrastive_naturalness_eval"
           end)

    File.rm!(output_path)
  end

  test "exports rows sorted by id" do
    output_path = "tmp_contrastive_naturalness_export_sorted.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} =
             ContrastiveNaturalnessTrainingExporter.export(output_path)

    ids =
      output_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)
      |> Enum.map(& &1["id"])

    assert ids == Enum.sort(ids)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert ContrastiveNaturalnessTrainingExporter.export(nil) ==
             {:error, :invalid_contrastive_naturalness_export_path}
  end
end
