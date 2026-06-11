defmodule Mix.Tasks.Procession.Training.ReviewCompare do
  @moduledoc """
  Compares two training review JSONL files by row id.

  This is intended for comparing a human-reviewed baseline against a later
  candidate run so changes can be reviewed line-by-line.

  Usage:

      mix procession.training.review_compare \\
        --baseline priv/training/reviews/npc_interaction_qe7d_exact_row_reviewed.jsonl \\
        --candidate priv/training/reviews/npc_interaction_qe7e_exact_row_auto_review.jsonl \\
        --out priv/training/reviews/npc_interaction_qe7e_vs_qe7d_review_compare.json
  """

  use Mix.Task

  @shortdoc "Compares training review rows by id"

  @rating_rank %{
    "pass" => 0,
    "minor" => 1,
    "fail" => 2,
    "reject" => 3
  }

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          baseline: :string,
          candidate: :string,
          out: :string
        ],
        aliases: [
          b: :baseline,
          c: :candidate,
          o: :out
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    baseline_path = required!(opts, :baseline)
    candidate_path = required!(opts, :candidate)
    out_path = required!(opts, :out)

    with {:ok, baseline_rows} <- load_jsonl(baseline_path),
         {:ok, candidate_rows} <- load_jsonl(candidate_path),
         {:ok, comparison} <- compare_rows(baseline_rows, candidate_rows),
         :ok <- write_json(out_path, comparison) do
      Mix.shell().info("Baseline rows: #{length(baseline_rows)}")
      Mix.shell().info("Candidate rows: #{length(candidate_rows)}")
      Mix.shell().info("Compared rows: #{length(comparison["rows"])}")
      Mix.shell().info("Output: #{out_path}")
      print_summary(comparison["rows"])
    else
      {:error, reason} ->
        Mix.raise("Failed to compare reviews: #{inspect(reason)}")
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

  defp compare_rows(baseline_rows, candidate_rows) do
    baseline_by_id = Map.new(baseline_rows, fn row -> {canonical_id(row["id"]), row} end)
    candidate_by_id = Map.new(candidate_rows, fn row -> {canonical_id(row["id"]), row} end)

    baseline_ids = MapSet.new(Map.keys(baseline_by_id))
    candidate_ids = MapSet.new(Map.keys(candidate_by_id))

    missing_from_candidate = MapSet.difference(baseline_ids, candidate_ids) |> MapSet.to_list()
    missing_from_baseline = MapSet.difference(candidate_ids, baseline_ids) |> MapSet.to_list()

    if missing_from_candidate != [] or missing_from_baseline != [] do
      {:error,
       %{
         missing_from_candidate: missing_from_candidate,
         missing_from_baseline: missing_from_baseline
       }}
    else
      rows =
        baseline_rows
        |> Enum.reduce_while({:ok, []}, fn baseline, {:ok, acc} ->
          canonical_baseline_id = canonical_id(baseline["id"])

          case Map.fetch(candidate_by_id, canonical_baseline_id) do
            {:ok, candidate} ->
              {:cont, {:ok, [compare_row(baseline, candidate) | acc]}}

            :error ->
              {:halt, {:error, {:missing_candidate_row, baseline["id"], canonical_baseline_id}}}
          end
        end)
        |> case do
          {:ok, rows} -> Enum.reverse(rows)
          {:error, reason} -> throw(reason)
        end

      {:ok,
       %{
         "summary" => summary(rows),
         "rows" => rows
       }}
    end
  end

  defp compare_row(baseline, candidate) do
    %{
      "id" => canonical_id(baseline["id"]),
      "expected" => candidate["expected"] || baseline["expected"],
      "baseline" => %{
        "rating" => baseline["rating"],
        "error_tags" => baseline["error_tags"] || [],
        "raw_generated" => baseline["raw_generated"],
        "training_note" => baseline["training_note"]
      },
      "candidate" => %{
        "rating" => candidate["rating"],
        "error_tags" => candidate["error_tags"] || [],
        "raw_generated" => candidate["raw_generated"],
        "training_note" => candidate["training_note"]
      },
      "comparison" => comparison_status(baseline, candidate),
      "needs_human_review" => needs_human_review?(baseline, candidate)
    }
  end

  defp comparison_status(baseline, candidate) do
    baseline_rank = rating_rank(baseline["rating"])
    candidate_rank = rating_rank(candidate["rating"])

    cond do
      candidate_rank < baseline_rank -> "improved"
      candidate_rank > baseline_rank -> "regressed"
      tags_changed?(baseline, candidate) -> "changed"
      true -> "same"
    end
  end

  defp needs_human_review?(baseline, candidate) do
    comparison_status(baseline, candidate) != "same" or
      baseline["rating"] != "pass" or
      candidate["rating"] != "pass"
  end

  defp tags_changed?(baseline, candidate) do
    MapSet.new(baseline["error_tags"] || []) != MapSet.new(candidate["error_tags"] || [])
  end

  defp rating_rank(rating), do: Map.get(@rating_rank, rating, 2)

  defp summary(rows) do
    rows
    |> Enum.frequencies_by(& &1["comparison"])
  end

  defp print_summary(rows) do
    Mix.shell().info("")
    Mix.shell().info("Comparison:")

    rows
    |> summary()
    |> Enum.sort_by(fn {status, count} -> {-count, status} end)
    |> Enum.each(fn {status, count} ->
      Mix.shell().info("  #{status}: #{count}")
    end)
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

  defp write_json(path, data) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write(path, Jason.encode!(data, pretty: true))
  end

  defp canonical_id(id) when is_binary(id) do
    id
    |> String.replace(~r/^(review_reinforcement_)+/, "")
  end

  defp canonical_id(id), do: id
end
