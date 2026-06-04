defmodule Procession.AI.NPCInteraction.QE6DRelationshipExpressionSFTExporter do
  @moduledoc """
  Exports the combined QE6d relationship-expression SFT dataset.

  QE6d combines:

  - QE6c combined relationship-expression rows
  - QE6d disclosure-control patch rows

  The disclosure patch teaches name-introduction variation, optional role
  disclosure, guarded non-answers, first-person preservation, and safer
  sensitive-role phrasing.
  """

  alias Procession.AI.NPCInteraction.QE6CRelationshipExpressionSFTExporter
  alias Procession.AI.NPCInteraction.QE6DDisclosureRelationshipExpressionSFTExporter

  @qe6c_output_path "tmp/training_exports/qe6d_qe6c_relationship_expression_sft.jsonl"
  @disclosure_output_path "tmp/training_exports/qe6d_disclosure_relationship_expression_sft.jsonl"

  @default_output_path "priv/training/exports/npc_interaction_qe6d_relationship_expression_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default combined QE6d relationship-expression SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports the combined QE6d relationship-expression SFT rows.
  """
  @spec export(Path.t()) :: export_result()
  def export(output_path) when is_binary(output_path) do
    with {:ok, qe6c_summary} <- QE6CRelationshipExpressionSFTExporter.export(@qe6c_output_path),
         {:ok, disclosure_summary} <-
           QE6DDisclosureRelationshipExpressionSFTExporter.export(@disclosure_output_path),
         {:ok, qe6c_rows} <- read_jsonl(@qe6c_output_path),
         {:ok, disclosure_rows} <- read_jsonl(@disclosure_output_path),
         rows <- qe6c_rows ++ disclosure_rows,
         :ok <- write_jsonl(output_path, rows) do
      {:ok,
       %{
         output_path: output_path,
         qe6c_count: qe6c_summary.exported_count,
         disclosure_count: disclosure_summary.exported_count,
         exported_count: length(rows)
       }}
    end
  end

  def export(_output_path),
    do: {:error, :invalid_qe6d_relationship_expression_sft_export_path}

  defp read_jsonl(path) do
    rows =
      path
      |> File.stream!()
      |> Enum.map(&Jason.decode!/1)

    {:ok, rows}
  rescue
    reason -> {:error, {:invalid_jsonl_export, path, reason}}
  end

  defp write_jsonl(output_path, rows) do
    output_path
    |> Path.dirname()
    |> File.mkdir_p!()

    contents =
      rows
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    File.write(output_path, contents <> "\n")
  end
end
