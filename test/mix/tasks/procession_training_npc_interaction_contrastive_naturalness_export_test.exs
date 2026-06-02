defmodule Mix.Tasks.ProcessionTrainingNpcInteractionContrastiveNaturalnessExportTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @output_path "priv/training/exports/npc_interaction_contrastive_naturalness_export.jsonl"

  setup do
    Mix.Task.reenable("procession.training.npc_interaction.contrastive_naturalness.export")
    File.rm(@output_path)

    on_exit(fn ->
      File.rm(@output_path)
    end)

    :ok
  end

  test "exports contrastive naturalness preference training rows" do
    output =
      capture_io(fn ->
        Mix.Tasks.Procession.Training.NpcInteraction.ContrastiveNaturalness.Export.run([])
      end)

    assert output =~ "Exported NPC interaction contrastive naturalness training rows."
    assert output =~ "Output: #{@output_path}"
    assert output =~ "Rows:"

    assert File.exists?(@output_path)

    rows =
      @output_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert length(rows) > 0

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["source"] == "contrastive_naturalness_eval"
           end)
  end
end
