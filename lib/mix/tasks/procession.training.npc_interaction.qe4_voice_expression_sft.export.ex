defmodule Mix.Tasks.Procession.Training.NpcInteraction.Qe4VoiceExpressionSft.Export do
  @moduledoc """
  Exports QE4 NPC interaction voice expression SFT rows.

      mix procession.training.npc_interaction.qe4_voice_expression_sft.export

  QE4 voice expression rows train the model to rewrite validated deterministic
  fallback responses into more character-specific dialogue using voice profiles
  and relationship stance context.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.QE4VoiceExpressionSFTExporter

  @shortdoc "Exports QE4 NPC interaction voice expression SFT rows"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case QE4VoiceExpressionSFTExporter.export_default() do
      {:ok, summary} ->
        Mix.shell().info("Exported QE4 NPC interaction voice expression SFT rows.")
        Mix.shell().info("Output: #{summary.output_path}")
        Mix.shell().info("Examples: #{summary.example_count}")
        Mix.shell().info("Total rows: #{summary.exported_count}")

      {:error, reason} ->
        Mix.raise("Failed to export QE4 NPC interaction voice expression SFT rows: #{inspect(reason)}")
    end
  end
end
