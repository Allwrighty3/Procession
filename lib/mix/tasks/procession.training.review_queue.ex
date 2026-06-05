defmodule Mix.Tasks.Procession.Training.ReviewQueue do
  @moduledoc """
  Extracts a human-editable review queue from a full auto-review JSONL file.

  The source file remains the complete canonical review artifact.
  The output file is a pretty JSON working queue containing only rows that
  need manual review.

  By default, rows with rating "pass" are excluded.

  Usage:

      mix procession.training.review_queue \\
        --source priv/training/reviews/npc_interaction_qe7c_exact_row_auto_review.jsonl \\
        --out priv/training/reviews/npc_interaction_qe7c_exact_row_review_queue.json

  Optional:

      --include-pass
  """

  use Mix.Task

  @shortdoc "Extracts a pretty JSON human review queue"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          source: :string,
          out: :string,
          include_pass: :boolean
        ],
        aliases: [
          s: :source,
          o: :out
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    source_path = required!(opts, :source)
    out_path = required!(opts, :out)
    include_pass? = Keyword.get(opts, :include_pass, false)

    with {:ok, rows} <- load_jsonl(source_path),
         queue_rows <- queue_rows(rows, include_pass?),
         compact_rows <- Enum.map(queue_rows, &compact_row/1),
         :ok <- write_queue_json(out_path, source_path, compact_rows) do
      Mix.shell().info("Wrote #{length(compact_rows)} review queue rows to #{out_path}")
    else
      {:error, reason} ->
        Mix.raise("Failed to create review queue: #{inspect(reason)}")
    end
  end

  defp required!(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> value
      :error -> Mix.raise("Missing required option: --#{String.replace(to_string(key), "_", "-")}")
    end
  end

  defp queue_rows(rows, true), do: rows

  defp queue_rows(rows, false) do
    Enum.reject(rows, fn row ->
      Map.get(row, "rating") == "pass"
    end)
  end

  defp compact_row(row) do
    %{
      "id" => row["id"],
      "expected" => row["expected"],
      "raw_generated" => row["raw_generated"],
      "rating" => row["rating"],
      "error_tags" => Map.get(row, "error_tags", []),
      "auto_review_notes" => Map.get(row, "auto_review_notes", []),
      "training_note" => Map.get(row, "training_note", "")
    }
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

  defp write_queue_json(path, source_path, rows) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    queue = %{
      "source_file" => source_path,
      "row_count" => length(rows),
      "instructions" => %{
        "edit_fields" => ["rating", "error_tags", "training_note"],
        "ratings" => ["pass", "minor", "fail", "reject"],
        "merge_back_with" => "mix procession.training.review_merge"
      },
      "rows" => rows
    }

    File.write(path, Jason.encode!(queue, pretty: true) <> "\n")
  end
end
