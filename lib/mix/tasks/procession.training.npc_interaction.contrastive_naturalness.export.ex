defmodule Mix.Tasks.Procession.Training.NpcInteraction.ContrastiveNaturalness.Export do
  @moduledoc """
  Exports NPC interaction contrastive naturalness eval cases into preference-style
  training JSONL.

      mix procession.training.npc_interaction.contrastive_naturalness.export

  Exported rows are non-authoritative training artifacts and must not be treated
  as authoritative simulation state.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessTrainingExporter

  @shortdoc "Exports NPC interaction contrastive naturalness preference training rows"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case ContrastiveNaturalnessTrainingExporter.export_default() do
      {:ok, summary} ->
        Mix.shell().info("Exported NPC interaction contrastive naturalness training rows.")
        Mix.shell().info("Output: #{summary.output_path}")
        Mix.shell().info("Rows: #{summary.exported_count}")

      {:error, reason} ->
        Mix.raise(
          "Failed to export NPC interaction contrastive naturalness training rows: #{inspect(reason)}"
        )
    end
  end
end
