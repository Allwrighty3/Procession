defmodule Procession.AI.NPCInteraction.QE2DSFTExporter do
  @moduledoc """
  Builds an augmented QE2d SFT dataset for NPC interaction training.

  QE2d combines:
  - the existing NPC interaction SFT export
  - chosen responses from contrastive naturalness eval cases
  - corrective role-boundary examples
  - corrective unknown-boundary examples

  Exported rows are non-authoritative training artifacts. They do not become
  simulation state and must not be treated as gameplay truth.
  """

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.RoleBoundaryExampleLoader
  alias Procession.AI.NPCInteraction.UnknownBoundaryExampleLoader

  @base_sft_path "priv/training/exports/npc_interaction_sft.jsonl"
  @default_output_path "priv/training/exports/npc_interaction_qe2d_sft.jsonl"

  @type export_result :: {:ok, map()} | {:error, term()}

  @doc """
  Exports the default QE2d SFT dataset.
  """
  @spec export_default() :: export_result()
  def export_default do
    export(@default_output_path)
  end

  @doc """
  Exports the QE2d SFT dataset to the given output path.
  """
  @spec export(Path.t()) :: export_result()
  def export(output_path) when is_binary(output_path) do
    with {:ok, base_rows} <- load_jsonl(@base_sft_path),
         {:ok, contrastive_cases} <- ContrastiveNaturalnessEvalCaseLoader.load_default(),
         {:ok, role_boundary_examples} <- RoleBoundaryExampleLoader.load_default(),
         {:ok, unknown_boundary_examples} <- UnknownBoundaryExampleLoader.load_default(),
         rows <-
           build_rows(
             base_rows,
             contrastive_cases,
             role_boundary_examples,
             unknown_boundary_examples
           ),
         :ok <- write_jsonl(output_path, rows) do
      {:ok,
       %{
         output_path: output_path,
         base_count: length(base_rows),
         contrastive_count: length(contrastive_cases),
         role_boundary_count: length(role_boundary_examples),
         unknown_boundary_count: length(unknown_boundary_examples),
         exported_count: length(rows)
       }}
    end
  end

  def export(_output_path), do: {:error, :invalid_qe2d_sft_export_path}

  defp build_rows(base_rows, contrastive_cases, role_boundary_examples, unknown_boundary_examples) do
    contrastive_rows =
      contrastive_cases
      |> Enum.map(&contrastive_case_to_sft_row/1)

    role_boundary_rows =
      role_boundary_examples
      |> Enum.map(&role_boundary_example_to_sft_row/1)

    unknown_boundary_rows =
      unknown_boundary_examples
      |> Enum.map(&unknown_boundary_example_to_sft_row/1)

    (base_rows ++ contrastive_rows ++ role_boundary_rows ++ unknown_boundary_rows)
    |> Enum.sort_by(&Map.get(&1, "id", ""))
  end

  defp contrastive_case_to_sft_row(eval_case) do
    text =
      eval_case
      |> prompt_for_case()
      |> append_response(eval_case["better_response"])

    %{
      "id" => "qe2d_contrastive_#{eval_case["id"]}",
      "text" => text,
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

  defp role_boundary_example_to_sft_row(example) do
    text =
      example
      |> prompt_for_case()
      |> append_response(example["response"])

    %{
      "id" => "qe2d_role_boundary_#{example["id"]}",
      "text" => text,
      "metadata" => %{
        "non_authoritative" => true,
        "source" => "role_boundary_example",
        "category" => "role_boundary",
        "target_id" => Map.get(example, "target_id"),
        "message" => Map.get(example, "message"),
        "notes" => Map.get(example, "notes")
      }
    }
  end

  defp unknown_boundary_example_to_sft_row(example) do
    text =
      example
      |> prompt_for_case()
      |> append_response(example["response"])

    %{
      "id" => "qe2d_unknown_boundary_#{example["id"]}",
      "text" => text,
      "metadata" => %{
        "non_authoritative" => true,
        "source" => "unknown_boundary_example",
        "category" => "unknown_boundary",
        "target_id" => Map.get(example, "target_id"),
        "message" => Map.get(example, "message"),
        "notes" => Map.get(example, "notes")
      }
    }
  end

  defp prompt_for_case(case_data) do
    context = %{
      "known_entities" => known_entities(),
      "known_locations" => known_locations(),
      "location_context" => nil,
      "memories" => [],
      "message" => case_data["message"],
      "scene_entities" => [target_for(case_data["target_id"])],
      "speaker" => %{
        "id" => "player",
        "name" => "Player",
        "type" => "player"
      },
      "target" => target_for(case_data["target_id"]),
      "world_context" => nil
    }

    """
    ### Task
    Respond as the target NPC using only the provided grounded context.
    Preserve each entity's role, location, and identity exactly.
    Do not transfer roles, locations, relationships, or current activities between entities.
    If current activity or an entity is unknown, say so naturally.
    Unknown people, places, relationships, and activities must not inherit traits from known entities.

    ### Context
    #{Jason.encode!(context, pretty: true)}

    ### Response
    """
    |> String.trim_trailing()
  end

  defp append_response(prompt, response) do
    prompt <> "\n" <> response
  end

  defp known_entities do
    [
      %{
        "id" => "npc_tobin",
        "name" => "Tobin",
        "type" => "npc",
        "role" => "merchant",
        "location" => "crossroads"
      },
      %{
        "id" => "npc_mira",
        "name" => "Mira",
        "type" => "npc",
        "role" => "innkeeper",
        "location" => "Briar Village"
      }
    ]
  end

  defp known_locations do
    [
      %{
        "id" => "loc_briar_village",
        "name" => "Briar Village",
        "type" => "settlement"
      },
      %{
        "id" => "loc_crossroads",
        "name" => "crossroads",
        "type" => "roadside"
      }
    ]
  end

  defp target_for("npc_tobin") do
    %{
      "id" => "npc_tobin",
      "name" => "Tobin",
      "type" => "npc",
      "role" => "merchant",
      "location" => "crossroads"
    }
  end

  defp target_for("npc_mira") do
    %{
      "id" => "npc_mira",
      "name" => "Mira",
      "type" => "npc",
      "role" => "innkeeper",
      "location" => "Briar Village"
    }
  end

  defp target_for(target_id) do
    %{
      "id" => target_id,
      "name" => target_id,
      "type" => "npc"
    }
  end

  defp load_jsonl(path) do
    with {:ok, contents} <- File.read(path) do
      contents
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reject(fn {line, _line_number} -> String.trim(line) == "" end)
      |> decode_lines()
    end
  end

  defp decode_lines(lines) do
    lines
    |> Enum.reduce_while({:ok, []}, fn {line, line_number}, {:ok, rows} ->
      case Jason.decode(line) do
        {:ok, decoded} ->
          {:cont, {:ok, [decoded | rows]}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_jsonl_line, line_number, reason}}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
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
