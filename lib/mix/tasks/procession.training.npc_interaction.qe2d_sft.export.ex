defmodule Mix.Tasks.Procession.Training.NpcInteraction.Qe2dSft.Export do
  @moduledoc """
  Exports an augmented QE2d NPC interaction SFT dataset.

      mix procession.training.npc_interaction.qe2d_sft.export

  QE2d combines:
  - the existing NPC interaction SFT export
  - chosen responses from contrastive naturalness eval cases
  - corrective role-boundary examples
  - corrective unknown-boundary examples

  Exported rows are non-authoritative training artifacts and must not be treated
  as authoritative simulation state.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.QE2DSFTExporter

  @shortdoc "Exports augmented QE2d NPC interaction SFT training rows"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case QE2DSFTExporter.export_default() do
      {:ok, summary} ->
        Mix.shell().info("Exported QE2d NPC interaction SFT training rows.")
        Mix.shell().info("Output: #{summary.output_path}")
        Mix.shell().info("Base rows: #{summary.base_count}")
        Mix.shell().info("Contrastive rows: #{summary.contrastive_count}")
        Mix.shell().info("Role-boundary rows: #{summary.role_boundary_count}")
        Mix.shell().info("Unknown-boundary rows: #{summary.unknown_boundary_count}")
        Mix.shell().info("Total rows: #{summary.exported_count}")

      {:error, reason} ->
        Mix.raise("Failed to export QE2d NPC interaction SFT rows: #{inspect(reason)}")
    end
  end
end
