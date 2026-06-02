defmodule Mix.Tasks.ProcessionEvalNpcInteractionNaturalnessTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup do
    Mix.Task.reenable("procession.eval.npc_interaction_naturalness")
    :ok
  end

  test "prints naturalness eval summary" do
    output =
      capture_io(fn ->
        Mix.Tasks.Procession.Eval.NpcInteractionNaturalness.run([])
      end)

    assert output =~ "NPC interaction naturalness eval summary:"
    assert output =~ "Total:"
    assert output =~ "Passed:"
    assert output =~ "Failed:"
  end
end
