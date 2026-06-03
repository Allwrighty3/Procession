defmodule Mix.Tasks.Procession.Training.NpcInteraction.Qe3ExpressionSft.Export do
  @moduledoc """
  Exports QE3 NPC interaction expression SFT rows.

      mix procession.training.npc_interaction.qe3_expression_sft.export

  QE3 expression rows train the model to rewrite validated deterministic
  fallback responses into more natural NPC dialogue without deciding truth.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.QE3ExpressionSFTExporter

  @shortdoc "Exports QE3 NPC interaction expression SFT rows"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case QE3ExpressionSFTExporter.export_default() do
      {:ok, summary} ->
        Mix.shell().info("Exported QE3 NPC interaction expression SFT rows.")
        Mix.shell().info("Output: #{summary.output_path}")
        Mix.shell().info("Examples: #{summary.example_count}")
        Mix.shell().info("Total rows: #{summary.exported_count}")

      {:error, reason} ->
        Mix.raise("Failed to export QE3 NPC interaction expression SFT rows: #{inspect(reason)}")
    end
  end
end
