defmodule Procession.AI.NPCInteraction.QE2BSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.QE2BSFTExporter
  alias Procession.AI.NPCInteraction.RoleBoundaryExampleLoader

  @base_sft_path "priv/training/exports/npc_interaction_sft.jsonl"

  test "exports augmented QE2b SFT rows" do
    output_path = "tmp_npc_interaction_qe2b_sft.jsonl"

    File.rm(output_path)

    assert {:ok, summary} = QE2BSFTExporter.export(output_path)

    assert summary.output_path == output_path
    assert summary.base_count > 0
    assert summary.contrastive_count > 0
    assert summary.role_boundary_count > 0

    assert summary.exported_count ==
             summary.base_count + summary.contrastive_count + summary.role_boundary_count

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
    output_path = "tmp_npc_interaction_qe2b_sft_base_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2BSFTExporter.export(output_path)

    base_ids =
      @base_sft_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])
      |> MapSet.new()

    qe2b_ids =
      output_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])
      |> MapSet.new()

    assert MapSet.subset?(base_ids, qe2b_ids)

    File.rm!(output_path)
  end

  test "adds contrastive chosen responses as SFT rows" do
    output_path = "tmp_npc_interaction_qe2b_sft_contrastive_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2BSFTExporter.export(output_path)
    assert {:ok, contrastive_cases} = ContrastiveNaturalnessEvalCaseLoader.load_default()

    rows = read_jsonl!(output_path)

    Enum.each(contrastive_cases, fn contrastive_case ->
      expected_id = "qe2b_contrastive_#{contrastive_case["id"]}"
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
    output_path = "tmp_npc_interaction_qe2b_sft_role_boundary_rows.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2BSFTExporter.export(output_path)
    assert {:ok, role_boundary_examples} = RoleBoundaryExampleLoader.load_default()

    rows = read_jsonl!(output_path)

    Enum.each(role_boundary_examples, fn example ->
      expected_id = "qe2b_role_boundary_#{example["id"]}"
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

  test "exports rows sorted by id" do
    output_path = "tmp_npc_interaction_qe2b_sft_sorted.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE2BSFTExporter.export(output_path)

    ids =
      output_path
      |> read_jsonl!()
      |> Enum.map(& &1["id"])

    assert ids == Enum.sort(ids)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE2BSFTExporter.export(nil) == {:error, :invalid_qe2b_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
