defmodule Mix.Tasks.Procession.Training.ReviewToSft do
  @moduledoc """
  Converts a reviewed training diagnostics JSONL file into SFT reinforcement rows.

  The reviewed file is expected to be the merged/full review artifact produced by:

      mix procession.training.review_merge

  The reviewed row's `expected` field is treated as the final human-reviewed
  target response. If a human provided `preferred_response` in the review queue,
  `review_merge` should already have applied it by overwriting `expected`.

  Usage:

      mix procession.training.review_to_sft \\
        --reviewed priv/training/reviews/npc_interaction_qe7c_exact_row_reviewed.jsonl \\
        --out priv/training/exports/npc_interaction_qe7d_reviewed_memory_expression_sft.jsonl

  Optional filters:

      --include-ratings pass,minor,fail,reject
      --include-tags over_disclosure,followup_not_allowed
      --category npc_interaction_qe7d_reviewed_memory_expression

  By default, all reviewed rows with ratings pass, minor, fail, or reject are included.
  """

  use Mix.Task

  @shortdoc "Converts reviewed NPC interaction diagnostics into SFT rows"

  @default_ratings ["pass", "minor", "fail", "reject"]
  @default_category "npc_interaction_review_reinforcement"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          reviewed: :string,
          sft: :string,
          out: :string,
          include_ratings: :string,
          include_tags: :string,
          category: :string
        ],
        aliases: [
          r: :reviewed,
          s: :sft,
          o: :out
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    reviewed_path = required!(opts, :reviewed)
    out_path = required!(opts, :out)
    sft_path = required!(opts, :sft)

    include_ratings =
      opts
      |> Keyword.get(:include_ratings)
      |> parse_csv(@default_ratings)

    include_tags =
      opts
      |> Keyword.get(:include_tags)
      |> parse_csv(nil)

    category = Keyword.get(opts, :category, @default_category)

    with {:ok, reviewed_rows} <- load_jsonl(reviewed_path),
         {:ok, sft_rows} <- load_jsonl(sft_path),
         selected_rows <- filter_rows(reviewed_rows, include_ratings, include_tags),
         {:ok, sft_rows_by_id} <- index_sft_rows(sft_rows),
         {:ok, reinforcement_rows} <-
           build_sft_rows(selected_rows, sft_rows_by_id, reviewed_path, category),
         :ok <- write_jsonl(out_path, reinforcement_rows) do
      Mix.shell().info("Reviewed rows: #{length(reviewed_rows)}")
      Mix.shell().info("Selected rows: #{length(selected_rows)}")
      Mix.shell().info("Source SFT rows: #{length(sft_rows)}")
      Mix.shell().info("Wrote SFT rows: #{length(reinforcement_rows)}")
      Mix.shell().info("Output: #{out_path}")
    else
      {:error, reason} ->
        Mix.raise("Failed to convert review to SFT: #{inspect(reason)}")
    end
  end

  defp required!(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} ->
        value

      :error ->
        Mix.raise("Missing required option: --#{String.replace(to_string(key), "_", "-")}")
    end
  end

  defp parse_csv(nil, default), do: default

  defp parse_csv(value, _default) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp filter_rows(rows, include_ratings, nil) do
    Enum.filter(rows, fn row ->
      Map.get(row, "rating") in include_ratings
    end)
  end

  defp filter_rows(rows, include_ratings, include_tags) do
    include_tags = MapSet.new(include_tags)

    Enum.filter(rows, fn row ->
      row_tags = MapSet.new(Map.get(row, "error_tags") || Map.get(row, "tags") || [])

      Map.get(row, "rating") in include_ratings and
        not MapSet.disjoint?(row_tags, include_tags)
    end)
  end

  defp build_sft_rows(rows, sft_rows_by_id, reviewed_path, category) do
    rows
    |> Enum.reduce_while({:ok, []}, fn row, {:ok, acc} ->
      case row_to_sft(row, sft_rows_by_id, reviewed_path, category) do
        {:ok, sft_row} -> {:cont, {:ok, [sft_row | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, sft_rows} -> {:ok, Enum.reverse(sft_rows)}
      error -> error
    end
  end

  defp row_to_sft(row, sft_rows_by_id, reviewed_path, category) do
    id = Map.get(row, "id")
    expected = row |> Map.get("expected") |> normalize_string()

    source_sft_row =
      if is_binary(id) do
        Map.get(sft_rows_by_id, id)
      else
        nil
      end

    prompt =
      row["prompt"] ||
        if is_map(source_sft_row), do: source_sft_row["prompt"], else: nil

    source_metadata =
      if is_map(source_sft_row), do: Map.get(source_sft_row, "metadata", %{}), else: %{}

    cond do
      not is_binary(id) or id == "" ->
        {:error, {:missing_id, row}}

      not is_map(source_sft_row) ->
        {:error, {:missing_sft_source_row, id}}

      not is_binary(prompt) or prompt == "" ->
        {:error, {:missing_prompt, id}}

      expected == "" ->
        {:error, {:missing_expected, id}}

      true ->
        {:ok,
         %{
           "id" => "review_reinforcement_#{id}",
           "prompt" => prompt,
           "completion" => expected,
           "text" => prompt <> "\n" <> expected,
           "metadata" => %{
             "non_authoritative" => true,
             "synthetic" => false,
             "source" => "training_review",
             "source_review_path" => reviewed_path,
             "category" => category,
             "reinforcement_source_id" => id,
             "phase" => Map.get(row, "phase"),
             "training_run" => Map.get(row, "training_run"),
             "eval_run" => Map.get(row, "eval_run"),
             "eval_set" => Map.get(row, "eval_set"),
             "review_rating" => Map.get(row, "rating"),
             "review_error_tags" => Map.get(row, "error_tags") || Map.get(row, "tags") || [],
             "review_training_note" => Map.get(row, "training_note", ""),
             "raw_generated" => Map.get(row, "raw_generated"),
             "expected" => expected,
             "human_reviewed" => Map.get(row, "human_reviewed", false),
             "original_metadata" => source_metadata
           }
         }}
    end
  end

  defp normalize_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_string(_value), do: ""

  defp load_jsonl(path) do
    rows =
      path
      |> File.stream!()
      |> Stream.with_index(1)
      |> Enum.map(fn {line, line_number} ->
        line = String.trim(line)

        if line == "" do
          nil
        else
          case Jason.decode(line) do
            {:ok, row} ->
              row

            {:error, reason} ->
              raise ArgumentError,
                    "Invalid JSON in #{path} on line #{line_number}: #{Exception.message(reason)}"
          end
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, rows}
  rescue
    reason -> {:error, reason}
  end

  defp write_jsonl(path, rows) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    contents =
      rows
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    File.write(path, contents <> "\n")
  end

  defp index_sft_rows(rows) do
    rows_by_id = Map.new(rows, fn row -> {row["id"], row} end)

    if map_size(rows_by_id) == length(rows) do
      {:ok, rows_by_id}
    else
      {:error, :duplicate_sft_row_ids}
    end
  end
end
