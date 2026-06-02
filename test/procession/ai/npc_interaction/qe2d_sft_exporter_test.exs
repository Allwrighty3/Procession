defmodule Procession.AI.NPCInteraction.QE2DSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.QE2DSFTExporter
  alias Procession.AI.NPCInteraction.RoleBoundaryExampleLoader
  alias Procession.AI.NPCInteraction.UnknownBoundaryExampleLoader

  @base_sft_path "priv/training/exports/npc_interaction_sft.jsonl"

  test "exports augmented QE2d SFT rows" do
    output_path = "tmp_npc_interaction_qe2d_sft.jsonl"

    File.rm(output_path)

    assert {:ok, summary} = QE2DSFTExporter.export(output_path)

    assert summary.output_path == output_path
    assert summary.base_count > 0
    assert summary.contrastive_count > 0
    assert summary.role_boundary_count > 0
    assert summary.unknown_boundary_count > 0

    assert summary.exported_count ==
             summary.base_count + summary.contrastive_count + summary.role_boundary_count +
               summary.unknown_boundary_count

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
    output_path = "tmp_npc_interaction_qe2d_sft_base_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2DSFTExporter.export(output_path)

    base_ids =
      @base_sft_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])
      |> MapSet.new()

    qe2d_ids =
      output_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])
      |> MapSet.new()

    assert MapSet.subset?(base_ids, qe2d_ids)

    File.rm!(output_path)
  end

  test "adds contrastive chosen responses as SFT rows" do
    output_path = "tmp_npc_interaction_qe2d_sft_contrastive_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2DSFTExporter.export(output_path)
    assert {:ok, contrastive_cases} = ContrastiveNaturalnessEvalCaseLoader.load_default()

    rows = read_jsonl!(output_path)

    Enum.each(contrastive_cases, fn contrastive_case ->
      expected_id = "qe2d_contrastive_#{contrastive_case["id"]}"
      row = Enum.find(rows, &(&1["id"] == expected_id))

      assert row
      assert row["text"] =~ contrastive_case["better_response"]
      refute row["text"] =~ contrastive_case["worse_response"]

      assert row["metadata"]["source"] == "contrastive_naturalness_eval"
      assert row["metadata"]["message"] == contrastive_case["message"]
      assert row["metadata"]["target_id"] == contrastive_case["target_id"]
    end)

    File.rm!(output_path)
  end

  test "adds role-boundary examples as SFT rows" do
    output_path = "tmp_npc_interaction_qe2d_sft_role_boundary_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2DSFTExporter.export(output_path)
    assert {:ok, role_boundary_examples} = RoleBoundaryExampleLoader.load_default()

    rows = read_jsonl!(output_path)

    Enum.each(role_boundary_examples, fn example ->
      expected_id = "qe2d_role_boundary_#{example["id"]}"
      row = Enum.find(rows, &(&1["id"] == expected_id))

      assert row
      assert row["text"] =~ "Preserve each entity's role, location, and identity exactly."
      assert row["text"] =~ example["response"]

      assert row["metadata"]["source"] == "role_boundary_example"
      assert row["metadata"]["category"] == "role_boundary"
      assert row["metadata"]["message"] == example["message"]
      assert row["metadata"]["target_id"] == example["target_id"]
    end)

    File.rm!(output_path)
  end

  test "adds unknown-boundary examples as SFT rows" do
    output_path = "tmp_npc_interaction_qe2d_sft_unknown_boundary_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2DSFTExporter.export(output_path)
    assert {:ok, unknown_boundary_examples} = UnknownBoundaryExampleLoader.load_default()

    rows = read_jsonl!(output_path)

    Enum.each(unknown_boundary_examples, fn example ->
      expected_id = "qe2d_unknown_boundary_#{example["id"]}"
      row = Enum.find(rows, &(&1["id"] == expected_id))

      assert row

      assert row["text"] =~
               "Unknown people, places, relationships, and activities must not inherit traits from known entities."

      assert row["text"] =~ example["response"]

      assert row["metadata"]["source"] == "unknown_boundary_example"
      assert row["metadata"]["category"] == "unknown_boundary"
      assert row["metadata"]["message"] == example["message"]
      assert row["metadata"]["target_id"] == example["target_id"]
    end)

    File.rm!(output_path)
  end

  test "exports rows sorted by id" do
    output_path = "tmp_npc_interaction_qe2d_sft_sorted.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2DSFTExporter.export(output_path)

    ids =
      output_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])

    assert ids == Enum.sort(ids)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE2DSFTExporter.export(nil) == {:error, :invalid_qe2d_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
