defmodule Procession.AI.NPCInteraction.QE2SFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.QE2SFTExporter

  @base_sft_path "priv/training/exports/npc_interaction_sft.jsonl"

  test "exports augmented QE2 SFT rows" do
    output_path = "tmp_npc_interaction_qe2_sft.jsonl"

    File.rm(output_path)

    assert {:ok, summary} = QE2SFTExporter.export(output_path)

    assert summary.output_path == output_path
    assert summary.base_count > 0
    assert summary.contrastive_count > 0
    assert summary.exported_count == summary.base_count + summary.contrastive_count

    rows = read_jsonl!(output_path)

    assert length(rows) == summary.exported_count

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               is_binary(row["text"]) and
               is_map(row["metadata"]) and
               row["metadata"]["non_authoritative"] == true
           end)

    File.rm!(output_path)
  end

  test "includes all base SFT rows" do
    output_path = "tmp_npc_interaction_qe2_sft_base_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2SFTExporter.export(output_path)

    base_ids =
      @base_sft_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])
      |> MapSet.new()

    qe2_ids =
      output_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])
      |> MapSet.new()

    assert MapSet.subset?(base_ids, qe2_ids)

    File.rm!(output_path)
  end

  test "adds contrastive chosen responses as SFT rows" do
    output_path = "tmp_npc_interaction_qe2_sft_contrastive_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2SFTExporter.export(output_path)
    assert {:ok, contrastive_cases} = ContrastiveNaturalnessEvalCaseLoader.load_default()

    rows = read_jsonl!(output_path)

    Enum.each(contrastive_cases, fn contrastive_case ->
      expected_id = "qe2_contrastive_#{contrastive_case["id"]}"

      row = Enum.find(rows, &(&1["id"] == expected_id))

      assert row
      assert row["text"] =~ "### Task"
      assert row["text"] =~ "### Context"
      assert row["text"] =~ "### Response"
      assert row["text"] =~ contrastive_case["better_response"]
      refute row["text"] =~ contrastive_case["worse_response"]

      assert row["metadata"]["source"] == "contrastive_naturalness_eval"
      assert row["metadata"]["message"] == contrastive_case["message"]
      assert row["metadata"]["target_id"] == contrastive_case["target_id"]
    end)

    File.rm!(output_path)
  end

  test "exports rows sorted by id" do
    output_path = "tmp_npc_interaction_qe2_sft_sorted.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2SFTExporter.export(output_path)

    ids =
      output_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])

    assert ids == Enum.sort(ids)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE2SFTExporter.export(nil) == {:error, :invalid_qe2_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
