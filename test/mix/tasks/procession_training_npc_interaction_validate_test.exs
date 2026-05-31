defmodule Mix.Tasks.ProcessionTrainingNpcInteractionValidateTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Procession.Training.NpcInteraction.Validate

  test "validates the default NPC interaction training corpus" do
    output =
      capture_io(fn ->
        Validate.run([])
      end)

    assert output =~ "Loaded 25 NPC interaction training examples."
    assert output =~ "NPC interaction training corpus is valid."
  end
end
