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

    decoded_ids =
      Enum.map(exported_lines, fn line ->
        line
        |> Jason.decode!()
        |> Map.fetch!("id")
      end)

    assert decoded_ids == Enum.sort(decoded_ids)

    first =
      exported_lines
      |> hd()
      |> Jason.decode!()

    assert first["id"] == "npc_concise_voice_tobin_answers_without_lore_dump"
    assert first["task"] == "npc_interaction"
    assert first["input"]["context"]["target"]["id"] == "npc_tobin"
    assert first["output"]["expected_response"] =~ "travelers"
    assert first["metadata"]["non_authoritative"] == true
    assert "question_drift" in first["metadata"]["failure_tags"]
  end
end
