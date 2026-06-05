defmodule Procession.AI.NPCInteraction.QE7CMemoryExpressionSFTExporter do
  @moduledoc """
  Exports the combined QE7c memory-expression SFT dataset.

  QE7c combines:

  - QE6d relationship/disclosure rows
  - QE7b memory-policy rows

  This prevents the memory adapter from overfitting on a tiny memory-only
  dataset and helps preserve relationship expression, disclosure control,
  first-person identity, and role grounding while adding recent-memory behavior.
  """

  alias Procession.AI.NPCInteraction.QE6DRelationshipExpressionSFTExporter
  alias Procession.AI.NPCInteraction.QE7BMemoryExpressionSFTExporter

  @qe6d_output_path "tmp/training_exports/qe7c_qe6d_relationship_expression_sft.jsonl"
  @qe7b_output_path "tmp/training_exports/qe7c_qe7b_memory_expression_sft.jsonl"

  @default_output_path "priv/training/exports/npc_interaction_qe7c_memory_expression_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default combined QE7c memory-expression SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports the combined QE7c memory-expression SFT rows.
  """
  @spec export(Path.t()) :: export_result()
  def export(output_path) when is_binary(output_path) do
    with {:ok, qe6d_summary} <- QE6DRelationshipExpressionSFTExporter.export(@qe6d_output_path),
         {:ok, qe7b_summary} <- QE7BMemoryExpressionSFTExporter.export(@qe7b_output_path),
         {:ok, qe6d_rows} <- read_jsonl(@qe6d_output_path),
         {:ok, qe7b_rows} <- read_jsonl(@qe7b_output_path),
         rows <- qe6d_rows ++ qe7b_rows,
         :ok <- write_jsonl(output_path, rows) do
      {:ok,
       %{
         output_path: output_path,
         qe6d_count: qe6d_summary.exported_count,
         qe7b_count: qe7b_summary.exported_count,
         exported_count: length(rows)
       }}
    end
  end

  def export(_output_path),
    do: {:error, :invalid_qe7c_memory_expression_sft_export_path}

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
