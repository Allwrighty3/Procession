defmodule Procession.AI.NPCInteraction.QE6DDisclosureRelationshipExpressionSFTExporter do
  @moduledoc """
  Exports QE6d disclosure-control relationship-expression SFT rows.

  These examples are non-authoritative synthetic patch data. They teach
  relationship-aware disclosure control, including name-only answers, guarded
  non-answers, optional role disclosure, safe sensitive-role phrasing, and
  first-person preservation.
  """

  alias Procession.AI.NPCInteraction.ResponseExpressionPrompt
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  @default_source_path "priv/training/npc_interaction_qe6d_relationship_expression_disclosure_patch_examples.jsonl"

  @default_output_path "priv/training/exports/npc_interaction_qe6d_disclosure_relationship_expression_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default QE6d disclosure-control relationship-expression SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports QE6d disclosure-control relationship-expression SFT rows.
  """
  @spec export(Path.t()) :: export_result()
  def export(output_path) when is_binary(output_path) do
    with {:ok, examples} <- VoiceExpressionExampleLoader.load(@default_source_path),
         {:ok, rows} <- build_rows(examples),
         :ok <- write_jsonl(output_path, rows) do
      {:ok,
       %{
         output_path: output_path,
         example_count: length(examples),
         exported_count: length(rows)
       }}
    end
  end

  def export(_output_path),
    do: {:error, :invalid_qe6d_disclosure_relationship_expression_sft_export_path}

  defp build_rows(examples) do
    examples
    |> Enum.reduce_while({:ok, []}, fn example, {:ok, rows} ->
      case example_to_row(example) do
        {:ok, row} -> {:cont, {:ok, [row | rows]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end

  defp example_to_row(example) do
    prompt_opts = [
      voice_profile: example["voice_profile"],
      relationship_stance: example["relationship_stance"],
      emotional_state: Map.get(example, "emotional_state", %{}),
      delivery_style: Map.get(example, "delivery_style", %{}),
      conversational_move: Map.get(example, "conversational_move", %{})
    ]

    with {:ok, prompt} <-
           ResponseExpressionPrompt.render(
             example["intent"],
             example["fallback_response"],
             prompt_opts
           ) do
      {:ok,
       %{
         "id" => "qe6d_disclosure_relationship_expression_#{example["id"]}",
         "prompt" => prompt,
         "completion" => example["response"],
         "text" => prompt <> "\n" <> example["response"],
         "metadata" => %{
           "non_authoritative" => true,
           "synthetic" => true,
           "source" => "npc_interaction_qe6d_disclosure_relationship_expression_example",
           "category" => "npc_interaction_qe6d_disclosure_relationship_expression",
           "fallback_response" => example["fallback_response"],
           "voice_profile" => example["voice_profile"],
           "relationship_stance" => example["relationship_stance"],
           "emotional_state" => Map.get(example, "emotional_state", %{}),
           "delivery_style" => Map.get(example, "delivery_style", %{}),
           "conversational_move" => Map.get(example, "conversational_move", %{}),
           "intent" => example["intent"],
           "notes" => Map.get(example, "notes")
         }
       }}
    end
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
