defmodule Mix.Tasks.ProcessionDemoNpcInteractionPipelineTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup do
    Mix.Task.reenable("procession.demo.npc_interaction_pipeline")
    :ok
  end

  test "prints deterministic NPC interaction pipeline demo output" do
    output =
      capture_io(fn ->
        Mix.Tasks.Procession.Demo.NpcInteractionPipeline.run([])
      end)

    assert output =~ "Case: tobin_about_mira"
    assert output =~ "Dialogue act: answer_known_entity"
    assert output =~ "Response: Mira is the innkeeper in Briar Village."

    assert output =~ "Case: tobin_self_identity"
    assert output =~ "Response: I'm Tobin, the merchant out by the crossroads."

    assert output =~ "Case: tobin_unknown_elandra"
    assert output =~ "Response: I don't know anyone named Elandra."
  end
end
