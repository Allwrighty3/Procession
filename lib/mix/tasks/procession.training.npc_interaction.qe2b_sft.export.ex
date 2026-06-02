defmodule Mix.Tasks.Procession.Training.NpcInteraction.Qe2bSft.Export do
  @moduledoc """
  Exports an augmented QE2b NPC interaction SFT dataset.

      mix procession.training.npc_interaction.qe2b_sft.export

  QE2b combines:
  - the existing NPC interaction SFT export
  - chosen responses from contrastive naturalness eval cases
  - corrective role-boundary examples

  Exported rows are non-authoritative training artifacts and must not be treated
  as authoritative simulation state.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.QE2BSFTExporter

  @shortdoc "Exports augmented QE2b NPC interaction SFT training rows"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case QE2BSFTExporter.export_default() do
      {:ok, summary} ->
        Mix.shell().info("Exported QE2b NPC interaction SFT training rows.")
        Mix.shell().info("Output: #{summary.output_path}")
        Mix.shell().info("Base rows: #{summary.base_count}")
        Mix.shell().info("Contrastive rows: #{summary.contrastive_count}")
        Mix.shell().info("Role-boundary rows: #{summary.role_boundary_count}")
        Mix.shell().info("Total rows: #{summary.exported_count}")

      {:error, reason} ->
        Mix.raise("Failed to export QE2b NPC interaction SFT rows: #{inspect(reason)}")
    end
  end
end
