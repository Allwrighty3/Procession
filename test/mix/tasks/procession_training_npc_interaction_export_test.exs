defmodule Mix.Tasks.ProcessionTrainingNpcInteractionExportTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Procession.Training.NpcInteraction.Export

  test "exports the default NPC interaction training corpus" do
    output_path =
      Path.join(
        System.tmp_dir!(),
        "npc_interaction_training_export_#{System.unique_integer([:positive])}.jsonl"
      )

    output =
      capture_io(fn ->
        Export.run(["--output", output_path])
      end)

    assert output =~ "Exported 25 NPC interaction training examples."
    assert output =~ "Output: #{output_path}"

    exported_lines =
      output_path
      |> File.read!()
      |> String.split("\n", trim: true)

    assert length(exported_lines) == 25

    first =
      exported_lines
      |> hd()
      |> Jason.decode!()

    assert first["id"] == "npc_identity_tobin_denies_being_mira"
    assert first["task"] == "npc_interaction"
    assert first["input"]["context"]["target"]["id"] == "npc_tobin"
    assert first["output"]["expected_response"] =~ "Tobin"
    assert first["metadata"]["non_authoritative"] == true
    assert "identity_drift" in first["metadata"]["failure_tags"]
  end
end
