defmodule Mix.Tasks.Procession.Training.ReviewSummary do
  @moduledoc """
  Summarizes NPC interaction training review JSONL files.

  Usage:

      mix procession.training.review_summary priv/training/reviews/npc_interaction_qe7c_exact_row_review.jsonl

  The task reports:

  - total reviewed rows
  - rating counts
  - error tag counts
  - training priorities by repeated error tags

  Review rows are expected to contain:

      {
        "rating": "fail",
        "error_tags": ["over_disclosure", "catchphrase_tail"]
      }
  """

  use Mix.Task

  @shortdoc "Summarizes NPC interaction training review JSONL files"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [path] ->
        summarize(path)

      [] ->
        Mix.raise("Expected review JSONL path, got none.")

      _ ->
        Mix.raise("Expected one review JSONL path, got: #{Enum.join(args, " ")}")
    end
  end

  defp summarize(path) do
    with {:ok, rows} <- load_rows(path) do
      rating_counts = count_by(rows, &Map.get(&1, "rating", "unrated"))

      tag_counts =
        rows
        |> Enum.flat_map(fn row -> Map.get(row, "error_tags") || Map.get(row, "tags") || [] end)
        |> Enum.frequencies()

      Mix.shell().info("")
      Mix.shell().info("Review: #{path}")
      Mix.shell().info("Rows: #{length(rows)}")

      Mix.shell().info("")
      Mix.shell().info("Ratings:")
      print_counts(rating_counts)

      Mix.shell().info("")
      Mix.shell().info("Error tags:")
      print_counts(tag_counts)

      Mix.shell().info("")
      Mix.shell().info("Training priorities:")

      tag_counts
      |> Enum.sort_by(fn {tag, count} -> {-count, tag} end)
      |> Enum.with_index(1)
      |> Enum.each(fn {{tag, count}, index} ->
        Mix.shell().info("  #{index}. #{tag}: #{count}")
      end)
    else
      {:error, reason} ->
        Mix.raise("Failed to summarize review file: #{inspect(reason)}")
    end
  end

  defp load_rows(path) do
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
                    "Invalid JSON on line #{line_number}: #{Exception.message(reason)}"
          end
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, rows}
  rescue
    reason -> {:error, reason}
  end

  defp count_by(rows, fun) do
    rows
    |> Enum.map(fun)
    |> Enum.frequencies()
  end

  defp print_counts(counts) when counts == %{} do
    Mix.shell().info("  none")
  end

  defp print_counts(counts) do
    counts
    |> Enum.sort_by(fn {key, count} -> {-count, key} end)
    |> Enum.each(fn {key, count} ->
      Mix.shell().info("  #{key}: #{count}")
    end)
  end
end
