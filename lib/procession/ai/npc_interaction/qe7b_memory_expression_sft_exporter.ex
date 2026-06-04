defmodule Procession.AI.NPCInteraction.QE7BMemoryExpressionSFTExporter do
  @moduledoc """
  Exports the combined QE7b memory-expression SFT dataset.

  QE7b combines:

  - QE7 base memory-expression rows
  - QE7b memory-policy patch rows

  The patch rows reinforce reference-policy obedience, irrelevant-memory
  ignoring, subtle allusion, and prevention of metadata/control-label leakage.
  """

  alias Procession.AI.NPCInteraction.QE7MemoryExpressionSFTExporter
  alias Procession.AI.NPCInteraction.QE7BMemoryPolicyPatchSFTExporter

  @qe7_output_path "tmp/training_exports/qe7b_qe7_memory_expression_sft.jsonl"
  @patch_output_path "tmp/training_exports/qe7b_memory_policy_patch_sft.jsonl"

  @default_output_path "priv/training/exports/npc_interaction_qe7b_memory_expression_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default combined QE7b memory-expression SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports the combined QE7b memory-expression SFT rows.
  """
  @spec export(Path.t()) :: export_result()
  def export(output_path) when is_binary(output_path) do
    with {:ok, qe7_summary} <- QE7MemoryExpressionSFTExporter.export(@qe7_output_path),
         {:ok, patch_summary} <- QE7BMemoryPolicyPatchSFTExporter.export(@patch_output_path),
         {:ok, qe7_rows} <- read_jsonl(@qe7_output_path),
         {:ok, patch_rows} <- read_jsonl(@patch_output_path),
         rows <- qe7_rows ++ patch_rows,
         :ok <- write_jsonl(output_path, rows) do
      {:ok,
       %{
         output_path: output_path,
         qe7_count: qe7_summary.exported_count,
         patch_count: patch_summary.exported_count,
         exported_count: length(rows)
       }}
    end
  end

  def export(_output_path),
    do: {:error, :invalid_qe7b_memory_expression_sft_export_path}

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
