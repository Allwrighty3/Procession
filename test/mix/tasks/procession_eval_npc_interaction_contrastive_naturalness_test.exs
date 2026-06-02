defmodule Mix.Tasks.ProcessionEvalNpcInteractionContrastiveNaturalnessTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup do
    Mix.Task.reenable("procession.eval.npc_interaction_contrastive_naturalness")
    :ok
  end

  test "prints contrastive naturalness eval summary" do
    output =
      capture_io(fn ->
        Mix.Tasks.Procession.Eval.NpcInteractionContrastiveNaturalness.run([])
      end)

    assert output =~ "NPC interaction contrastive naturalness eval summary:"
    assert output =~ "Total:"
    assert output =~ "Passed:"
    assert output =~ "Failed:"
  end
end
