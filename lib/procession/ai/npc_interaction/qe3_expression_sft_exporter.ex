defmodule Procession.AI.NPCInteraction.QE3ExpressionSFTExporter do
  @moduledoc """
  Exports QE3 NPC interaction expression SFT rows.

  QE3 trains the model to rewrite validated deterministic fallback responses
  into more natural NPC dialogue. It does not train the model to decide truth,
  entity identity, relationships, roles, locations, or gameplay state.
  """

  alias Procession.AI.NPCInteraction.ExpressionExampleLoader
  alias Procession.AI.NPCInteraction.InteractionPipeline
  alias Procession.AI.NPCInteraction.ResponseExpressionPrompt

  @default_output_path "priv/training/exports/npc_interaction_qe3_expression_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default QE3 expression SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports QE3 expression SFT rows to the given output path.
  """
  @spec export(Path.t()) :: export_result()
  def export(output_path) when is_binary(output_path) do
    with {:ok, examples} <- ExpressionExampleLoader.load_default(),
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

  def export(_output_path), do: {:error, :invalid_qe3_expression_sft_export_path}

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
    context = context_for_example(example)

    with {:ok, pipeline_result} <- InteractionPipeline.respond(context),
         :ok <- ensure_fallback_matches(example, pipeline_result.fallback_response),
         {:ok, prompt} <-
           ResponseExpressionPrompt.render(
             pipeline_result.intent,
             pipeline_result.fallback_response
           ) do
      {:ok,
       %{
         "id" => "qe3_expression_#{example["id"]}",
         "prompt" => prompt,
         "response" => example["response"],
         "text" => prompt <> "\n" <> example["response"],
         "metadata" => %{
           "non_authoritative" => true,
           "source" => "npc_interaction_expression_example",
           "category" => "npc_interaction_expression",
           "target_id" => example["target_id"],
           "message" => example["message"],
           "fallback_response" => example["fallback_response"],
           "notes" => Map.get(example, "notes")
         }
       }}
    end
  end

  defp ensure_fallback_matches(example, fallback_response) do
    expected = String.trim(example["fallback_response"])
    actual = String.trim(fallback_response)

    if expected == actual do
      :ok
    else
      {:error,
       {:fallback_response_mismatch,
        %{
          id: example["id"],
          expected: expected,
          actual: actual
        }}}
    end
  end

  defp context_for_example(example) do
    %{
      "known_entities" => [
        entity("npc_tobin"),
        entity("npc_mira")
      ],
      "message" => example["message"],
      "target" => entity(example["target_id"])
    }
  end

  defp entity("npc_tobin") do
    %{
      "id" => "npc_tobin",
      "name" => "Tobin",
      "type" => "npc",
      "role" => "merchant",
      "location" => "crossroads"
    }
  end

  defp entity("npc_mira") do
    %{
      "id" => "npc_mira",
      "name" => "Mira",
      "type" => "npc",
      "role" => "innkeeper",
      "location" => "Briar Village"
    }
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
