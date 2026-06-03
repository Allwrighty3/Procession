defmodule Mix.Tasks.ProcessionTrainingNpcInteractionQe4VoiceExpressionSftExportTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @output_path "priv/training/exports/npc_interaction_qe4_voice_expression_sft.jsonl"

  setup do
    Mix.Task.reenable("procession.training.npc_interaction.qe4_voice_expression_sft.export")
    File.rm(@output_path)

    on_exit(fn ->
      File.rm(@output_path)
    end)

    :ok
  end

  test "exports QE4 NPC interaction voice expression SFT rows" do
    output =
      capture_io(fn ->
        Mix.Tasks.Procession.Training.NpcInteraction.Qe4VoiceExpressionSft.Export.run([])
      end)

    assert output =~ "Exported QE4 NPC interaction voice expression SFT rows."
    assert output =~ "Output: #{@output_path}"
    assert output =~ "Examples:"
    assert output =~ "Total rows:"

    assert File.exists?(@output_path)

    rows =
      @output_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert length(rows) >= 12

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["category"] == "npc_interaction_voice_expression"
           end)
  end
end
