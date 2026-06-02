defmodule Mix.Tasks.Procession.Training.NpcInteraction.Qe2Sft.Export do
  @moduledoc """
  Exports an augmented QE2 NPC interaction SFT dataset.

      mix procession.training.npc_interaction.qe2_sft.export

  QE2 combines the existing NPC interaction SFT export with chosen responses from
  contrastive naturalness eval cases.

  Exported rows are non-authoritative training artifacts and must not be treated
  as authoritative simulation state.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.QE2SFTExporter

  @shortdoc "Exports augmented QE2 NPC interaction SFT training rows"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case QE2SFTExporter.export_default() do
      {:ok, summary} ->
        Mix.shell().info("Exported QE2 NPC interaction SFT training rows.")
        Mix.shell().info("Output: #{summary.output_path}")
        Mix.shell().info("Base rows: #{summary.base_count}")
        Mix.shell().info("Contrastive rows: #{summary.contrastive_count}")
        Mix.shell().info("Total rows: #{summary.exported_count}")

      {:error, reason} ->
        Mix.raise("Failed to export QE2 NPC interaction SFT rows: #{inspect(reason)}")
    end
  end
end
