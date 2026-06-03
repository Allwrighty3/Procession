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

    assert output =~ "Case: tobin_not_innkeeper"
    assert output =~ "Dialogue act: reject_false_role"
    assert output =~ "No, Mira is the innkeeper. I'm Tobin, the merchant out by the crossroads."

    assert output =~ "Case: tobin_mira_not_sister"
    assert output =~ "Dialogue act: reject_false_relationship"
    assert output =~ "No, Mira isn't family. Mira is the innkeeper in Briar Village."

    assert output =~ "Case: tobin_mira_current_activity_unknown"

    assert output =~
             "I don't know what Mira is doing right now. Mira is the innkeeper in Briar Village."

    assert output =~ "Case: tobin_where_is_mira"
    assert output =~ "Dialogue act: answer_known_location"

    assert output =~
             "Mira is associated with Briar Village. I don't know where they are right now."

    assert output =~ "Case: safe_candidate_about_mira"
    assert output =~ "Candidate: \"Mira keeps the inn in Briar Village.\""
    assert output =~ "Response source: candidate"
    assert output =~ "Response: Mira keeps the inn in Briar Village."

    assert output =~ "Case: unsafe_candidate_unknown_elandra"
    assert output =~ "Candidate: \"Elandra is a merchant at the crossroads.\""
    assert output =~ "Response source: deterministic"
    assert output =~ "Response: I don't know anyone named Elandra."
    assert output =~ "Fallback: I don't know anyone named Elandra."
    assert output =~ "unknown_trait_invention"

    assert output =~ "Case: safe_expression_adapter_about_mira"
    assert output =~ "Expression adapter: safe"
    assert output =~ "Response source: expression_candidate"
    assert output =~ "Response: Mira keeps the inn in Briar Village."
    assert output =~ "Expression candidate: Mira keeps the inn in Briar Village."

    assert output =~ "Case: unsafe_expression_adapter_unknown_elandra"
    assert output =~ "Expression adapter: unsafe"
    assert output =~ "Response source: deterministic"
    assert output =~ "Response: I don't know anyone named Elandra."
    assert output =~ "Expression candidate: Elandra is a merchant at the crossroads."
    assert output =~ "unknown_trait_invention"
  end
end
