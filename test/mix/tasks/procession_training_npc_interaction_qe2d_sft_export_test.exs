defmodule Mix.Tasks.ProcessionTrainingNpcInteractionQe2dSftExportTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @output_path "priv/training/exports/npc_interaction_qe2d_sft.jsonl"

  setup do
    Mix.Task.reenable("procession.training.npc_interaction.qe2d_sft.export")
    File.rm(@output_path)

    on_exit(fn ->
      File.rm(@output_path)
    end)

    :ok
  end

  test "exports augmented QE2d SFT training rows" do
    output =
      capture_io(fn ->
        Mix.Tasks.Procession.Training.NpcInteraction.Qe2dSft.Export.run([])
      end)

    assert output =~ "Exported QE2d NPC interaction SFT training rows."
    assert output =~ "Output: #{@output_path}"
    assert output =~ "Base rows:"
    assert output =~ "Contrastive rows:"
    assert output =~ "Role-boundary rows:"
    assert output =~ "Unknown-boundary rows:"
    assert output =~ "Total rows:"

    assert File.exists?(@output_path)

    rows =
      @output_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert length(rows) > 0

    assert Enum.any?(rows, fn row ->
             String.starts_with?(row["id"], "qe2d_contrastive_") and
               row["metadata"]["source"] == "contrastive_naturalness_eval"
           end)

    assert Enum.any?(rows, fn row ->
             String.starts_with?(row["id"], "qe2d_role_boundary_") and
               row["metadata"]["source"] == "role_boundary_example"
           end)

    assert Enum.any?(rows, fn row ->
             String.starts_with?(row["id"], "qe2d_unknown_boundary_") and
               row["metadata"]["source"] == "unknown_boundary_example"
           end)

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true
           end)
  end
end
