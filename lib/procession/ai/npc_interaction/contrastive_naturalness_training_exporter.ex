defmodule Procession.AI.NPCInteraction.ContrastiveNaturalnessTrainingExporter do
  @moduledoc """
  Exports NPC interaction contrastive naturalness eval cases into preference-style
  training rows.

  Exported rows are non-authoritative training artifacts. They do not become
  simulation state and should not be treated as gameplay truth.
  """

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalScorer

  @default_output_path "priv/training/exports/npc_interaction_contrastive_naturalness_export.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports default contrastive naturalness cases to the default export path.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports default contrastive naturalness cases to the given output path.
  """
  @spec export(Path.t()) :: export_result()
  def export(output_path) when is_binary(output_path) do
    with {:ok, cases} <- ContrastiveNaturalnessEvalCaseLoader.load_default(),
         :ok <- validate_cases(cases),
         rows <- build_rows(cases),
         :ok <- write_jsonl(output_path, rows) do
      {:ok,
       %{
         output_path: output_path,
         exported_count: length(rows)
       }}
    end
  end

  def export(_output_path), do: {:error, :invalid_contrastive_naturalness_export_path}

  defp validate_cases(cases) do
    summary = ContrastiveNaturalnessEvalScorer.score_cases(cases)

    if summary.failed == 0 do
      :ok
    else
      {:error, {:invalid_contrastive_naturalness_cases, summary}}
    end
  end

  defp build_rows(cases) do
    cases
    |> Enum.sort_by(&Map.get(&1, "id", ""))
    |> Enum.map(&build_row/1)
  end

  defp build_row(eval_case) do
    %{
      "id" => eval_case["id"],
      "prompt" => prompt_for_case(eval_case),
      "chosen" => eval_case["better_response"],
      "rejected" => eval_case["worse_response"],
      "metadata" => %{
        "non_authoritative" => true,
        "source" => "contrastive_naturalness_eval",
        "category" => Map.get(eval_case, "category"),
        "target_id" => Map.get(eval_case, "target_id"),
        "message" => Map.get(eval_case, "message"),
        "preference_reasons" => Map.get(eval_case, "preference_reasons", [])
      }
    }
  end

  defp prompt_for_case(eval_case) do
    """
    ### Task
    Choose the NPC response that is more grounded, conversational, and natural.

    ### Player Message
    #{eval_case["message"]}

    ### Target NPC
    #{eval_case["target_id"]}

    ### Preference Criteria
    Prefer the response that:
    - answers the player's actual question
    - speaks as the target NPC
    - stays grounded
    - avoids invented relationships, locations, or current activity
    - avoids JSON, explanations, narrator voice, and prompt residue
    - sounds like natural NPC dialogue

    ### Response
    """
    |> String.trim()
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
