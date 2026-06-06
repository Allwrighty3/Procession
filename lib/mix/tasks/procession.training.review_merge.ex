defmodule Mix.Tasks.Procession.Training.ReviewMerge do
  @moduledoc """
  Merges a human-edited review queue back into a full review JSONL file.

  Rows are matched by `id`.

  The reviewed queue is treated as a patch. It updates only human-review fields
  on the full source row and preserves canonical metadata, run info, confidence,
  and auto-review notes from the source file.

  Usage:

      mix procession.training.review_merge \\
        --source priv/training/reviews/npc_interaction_qe7c_exact_row_auto_review.jsonl \\
        --reviewed priv/training/reviews/npc_interaction_qe7c_exact_row_review_queue.json \\
        --out priv/training/reviews/npc_interaction_qe7c_exact_row_reviewed.jsonl
  """

  use Mix.Task

  @shortdoc "Merges reviewed queue fields back into full review JSONL"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          source: :string,
          reviewed: :string,
          out: :string
        ],
        aliases: [
          s: :source,
          r: :reviewed,
          o: :out
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    source_path = required!(opts, :source)
    reviewed_path = required!(opts, :reviewed)
    out_path = required!(opts, :out)

    with {:ok, source_rows} <- load_jsonl(source_path),
         {:ok, reviewed_rows} <- load_reviewed_rows(reviewed_path),
         {:ok, merged_rows} <- merge_rows(source_rows, reviewed_rows),
         :ok <- write_jsonl(out_path, merged_rows) do
      Mix.shell().info("Merged #{length(reviewed_rows)} reviewed rows into #{out_path}")
      Mix.shell().info("Total rows: #{length(merged_rows)}")
    else
      {:error, reason} ->
        Mix.raise("Failed to merge reviewed rows: #{inspect(reason)}")
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

  defp load_reviewed_rows(path) do
    case Path.extname(path) do
      ".json" ->
        with {:ok, review} <- load_json(path) do
          {:ok, Map.get(review, "rows", [])}
        end

      _ ->
        load_jsonl(path)
    end
  end

  defp load_json(path) do
    path
    |> File.read!()
    |> Jason.decode()
  rescue
    reason -> {:error, reason}
  end

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

  defp merge_rows(source_rows, reviewed_rows) do
    reviewed_by_id = Map.new(reviewed_rows, fn row -> {row["id"], row} end)
    source_ids = MapSet.new(Enum.map(source_rows, & &1["id"]))

    missing_ids =
      reviewed_by_id
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(source_ids, &1))

    if missing_ids != [] do
      {:error, {:reviewed_rows_missing_from_source, missing_ids}}
    else
      merged_rows =
        Enum.map(source_rows, fn source_row ->
          case Map.fetch(reviewed_by_id, source_row["id"]) do
            {:ok, reviewed_row} -> apply_review(source_row, reviewed_row)
            :error -> source_row
          end
        end)

      {:ok, merged_rows}
    end
  end

  defp apply_review(source_row, reviewed_row) do
    preferred_response =
      reviewed_row
      |> Map.get("preferred_response", "")
      |> normalize_string()

    expected =
      if preferred_response == "" do
        Map.get(source_row, "expected", "")
      else
        preferred_response
      end

    source_row
    |> Map.put("expected", expected)
    |> Map.put("rating", reviewed_row["rating"])
    |> Map.put(
      "error_tags",
      Map.get(reviewed_row, "error_tags") || Map.get(reviewed_row, "tags") || []
    )
    |> Map.delete("preferred_response")
    |> Map.put(
      "training_note",
      Map.get(reviewed_row, "training_note") || Map.get(reviewed_row, "note") || ""
    )
    |> Map.put("human_reviewed", true)
  end

  defp normalize_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_string(_value), do: ""

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
end
