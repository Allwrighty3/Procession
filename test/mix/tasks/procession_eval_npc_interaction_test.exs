defmodule Mix.Tasks.ProcessionEvalNpcInteractionTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Procession.Eval.NpcInteraction

  setup do
    Mix.Task.reenable("procession.eval.npc_interaction")
    :ok
  end

  test "loads and prints NPC interaction eval cases without calling Ollama" do
    output =
      capture_io(fn ->
        NpcInteraction.run([])
      end)

    assert output =~ "Loaded 10 NPC interaction eval cases."
    assert output =~ "- known_entity_identity_tobin_about_mira"
    assert output =~ "- unknown_entity_uncertainty"
    assert output =~ "- field_boundary_player_not_innkeeper"
  end
end
