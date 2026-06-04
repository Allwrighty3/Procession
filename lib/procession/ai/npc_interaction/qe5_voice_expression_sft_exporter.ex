defmodule Procession.AI.NPCInteraction.QE5VoiceExpressionSFTExporter do
  @moduledoc """
  Exports qe5 NPC interaction voice expression SFT rows.

  qe5 trains the model to rewrite validated deterministic fallback responses
  into more character-specific dialogue using voice profiles and relationship
  stance context.

  It does not train the model to decide truth, entity identity, relationships,
  roles, locations, current activity, or gameplay state.
  """

  alias Procession.AI.NPCInteraction.InteractionPipeline
  alias Procession.AI.NPCInteraction.ResponseExpressionPrompt
  alias Procession.AI.NPCInteraction.VoiceExpressionExampleLoader

  @default_source_path "priv/training/npc_interaction_qe5_voice_expression_examples.jsonl"
  @default_output_path "priv/training/exports/npc_interaction_qe5_voice_expression_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default qe5 voice expression SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports qe5 voice expression SFT rows to the given output path.
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

  def export(_output_path), do: {:error, :invalid_qe5_voice_expression_sft_export_path}

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

    prompt_opts = [
      voice_profile: example["voice_profile"],
      relationship_stance: example["relationship_stance"],
      emotional_state: Map.get(example, "emotional_state", %{}),
      delivery_style: Map.get(example, "delivery_style", %{}),
      conversational_move: Map.get(example, "conversational_move", %{})
    ]

    with {:ok, pipeline_result} <- InteractionPipeline.respond(context),
         :ok <- ensure_fallback_matches(example, pipeline_result.fallback_response),
         {:ok, prompt} <-
           ResponseExpressionPrompt.render(
             pipeline_result.intent,
             pipeline_result.fallback_response,
             prompt_opts
           ) do
      {:ok,
       %{
         "id" => "qe5_voice_expression_#{example["id"]}",
         "prompt" => prompt,
         "completion" => example["response"],
         "text" => prompt <> "\n" <> example["response"],
         "metadata" => %{
           "non_authoritative" => true,
           "source" => "npc_interaction_qe5_voice_expression_example",
           "category" => "npc_interaction_qe5_voice_expression",
           "target_id" => example["target_id"],
           "message" => example["message"],
           "fallback_response" => example["fallback_response"],
           "voice_profile" => example["voice_profile"],
           "relationship_stance" => example["relationship_stance"],
           "emotional_state" => Map.get(example, "emotional_state", %{}),
           "notes" => Map.get(example, "notes"),
           "delivery_style" => Map.get(example, "delivery_style", %{}),
           "conversational_move" => Map.get(example, "conversational_move", %{})
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
      "known_entities" => known_entities(),
      "message" => example["message"],
      "target" => entity(example["target_id"])
    }
  end

  defp known_entities do
    [
      entity("npc_tobin"),
      entity("npc_mira"),
      entity("npc_guard"),
      entity("npc_miner"),
      entity("npc_child")
    ]
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

  defp entity("npc_guard") do
    %{
      "id" => "npc_guard",
      "name" => "Guard",
      "type" => "npc",
      "role" => "guard",
      "location" => "gatehouse"
    }
  end

  defp entity("npc_miner") do
    %{
      "id" => "npc_miner",
      "name" => "Miner",
      "type" => "npc",
      "role" => "miner",
      "location" => "old mine"
    }
  end

  defp entity("npc_child") do
    %{
      "id" => "npc_child",
      "name" => "Child",
      "type" => "npc",
      "role" => "child",
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
