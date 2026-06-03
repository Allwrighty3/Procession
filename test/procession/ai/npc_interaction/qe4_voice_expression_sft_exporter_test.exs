defmodule Procession.AI.NPCInteraction.QE4VoiceExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE4VoiceExpressionSFTExporter
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  test "exports QE4 voice expression SFT rows" do
    output_path = "tmp_npc_interaction_qe4_voice_expression_sft.jsonl"

    File.rm(output_path)

    assert {:ok, summary} = QE4VoiceExpressionSFTExporter.export(output_path)
    assert {:ok, examples} = VoiceExpressionExampleLoader.load_default()

    assert summary.output_path == output_path
    assert summary.example_count == length(examples)
    assert summary.exported_count == length(examples)

    rows = read_jsonl!(output_path)

    assert length(rows) == length(examples)

    assert Enum.all?(rows, fn row ->
             is_binary(row["id"]) and
               String.starts_with?(row["id"], "qe4_voice_expression_") and
               is_binary(row["prompt"]) and
               is_binary(row["completion"]) and
               is_binary(row["text"]) and
               is_map(row["metadata"])
           end)

    assert Enum.all?(rows, fn row ->
             row["text"] == row["prompt"] <> "\n" <> row["completion"]
           end)

    File.rm!(output_path)
  end

  test "exports prompts with expression context" do
    output_path = "tmp_npc_interaction_qe4_voice_expression_prompt_shape.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE4VoiceExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["prompt"] =~ "### Expression Context" and
               row["prompt"] =~ "voice_profile" and
               row["prompt"] =~ "relationship_stance" and
               row["prompt"] =~ "may_use_subjective_opinion" and
               row["prompt"] =~ "may_omit_nonessential_known_facts"
           end)

    assert Enum.any?(rows, fn row ->
             row["id"] == "qe4_voice_expression_voice_mira_haughty_tobin_idiot" and
               row["prompt"] =~ "\"tone\": \"haughty\"" and
               row["prompt"] =~ "\"attitude\": \"dismissive\"" and
               row["completion"] == "Tobin? The idiot at the crossroads? Not a chance."
           end)

    File.rm!(output_path)
  end

  test "marks exported rows as non-authoritative voice expression data" do
    output_path = "tmp_npc_interaction_qe4_voice_expression_metadata.jsonl"

    File.rm(output_path)

    assert {:ok, _summary} = QE4VoiceExpressionSFTExporter.export(output_path)

    rows = read_jsonl!(output_path)

    assert Enum.all?(rows, fn row ->
             row["metadata"]["non_authoritative"] == true and
               row["metadata"]["source"] == "npc_interaction_voice_expression_example" and
               row["metadata"]["category"] == "npc_interaction_voice_expression" and
               is_map(row["metadata"]["voice_profile"]) and
               is_map(row["metadata"]["relationship_stance"])
           end)

    File.rm!(output_path)
  end

  test "rejects invalid output path" do
    assert QE4VoiceExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe4_voice_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
