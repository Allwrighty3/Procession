defmodule Procession.AI.NPCInteraction.QE6CSyntheticRelationshipExpressionSFTExporter do
  @moduledoc """
  Exports synthetic QE6c relationship-expression SFT rows.

  These examples are non-authoritative generalization data. They are used to
  teach relationship-aware expression across varied names, roles, moods, and
  listener/subject relationships without adding those entities to canon.

  Unlike canonical QE6 exporters, this exporter does not call the deterministic
  interaction pipeline. Each row carries its own already-grounded intent and
  fallback response.
  """

  alias Procession.AI.NPCInteraction.ResponseExpressionPrompt
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  @default_source_path "priv/training/npc_interaction_qe6c_relationship_expression_synthetic_examples.jsonl"

  @default_output_path "priv/training/exports/npc_interaction_qe6c_synthetic_relationship_expression_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default QE6c synthetic relationship-expression SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports QE6c synthetic relationship-expression SFT rows to the given output path.
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
    do: {:error, :invalid_qe6c_synthetic_relationship_expression_sft_export_path}

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
         "id" => "qe6c_synthetic_relationship_expression_#{example["id"]}",
         "prompt" => prompt,
         "completion" => example["response"],
         "text" => prompt <> "\n" <> example["response"],
         "metadata" => %{
           "non_authoritative" => true,
           "synthetic" => true,
           "source" => "npc_interaction_qe6c_synthetic_relationship_expression_example",
           "category" => "npc_interaction_qe6c_synthetic_relationship_expression",
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
