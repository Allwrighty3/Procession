defmodule Procession.AI.NPCInteraction.QE6CRelationshipExpressionSFTExporter do
  @moduledoc """
  Exports the combined QE6c relationship-expression SFT dataset.

  QE6c combines:

  - canonical QE6 relationship-expression rows
  - canonical QE6b patch rows
  - synthetic QE6c generalization rows

  Synthetic rows are non-authoritative and exist to teach generalization across
  varied names, roles, moods, and relationship structures.
  """

  alias Procession.AI.NPCInteraction.QE6BRelationshipExpressionSFTExporter
  alias Procession.AI.NPCInteraction.QE6CSyntheticRelationshipExpressionSFTExporter

  @canonical_output_path "tmp/training_exports/qe6c_canonical_relationship_expression_sft.jsonl"
  @synthetic_output_path "tmp/training_exports/qe6c_synthetic_relationship_expression_sft.jsonl"

  @default_output_path "priv/training/exports/npc_interaction_qe6c_relationship_expression_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default combined QE6c relationship-expression SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports the combined QE6c relationship-expression SFT rows.
  """
  @spec export(Path.t()) :: export_result()
  def export(output_path) when is_binary(output_path) do
    with {:ok, canonical_summary} <-
           QE6BRelationshipExpressionSFTExporter.export(@canonical_output_path),
         {:ok, synthetic_summary} <-
           QE6CSyntheticRelationshipExpressionSFTExporter.export(@synthetic_output_path),
         {:ok, canonical_rows} <- read_jsonl(@canonical_output_path),
         {:ok, synthetic_rows} <- read_jsonl(@synthetic_output_path),
         rows <- canonical_rows ++ synthetic_rows,
         :ok <- write_jsonl(output_path, rows) do
      {:ok,
       %{
         output_path: output_path,
         canonical_count: canonical_summary.exported_count,
         synthetic_count: synthetic_summary.exported_count,
         exported_count: length(rows)
       }}
    end
  end

  def export(_output_path),
    do: {:error, :invalid_qe6c_relationship_expression_sft_export_path}

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
