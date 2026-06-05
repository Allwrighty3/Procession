defmodule Mix.Tasks.Procession.Training.ReviewDraft do
  @moduledoc """
  Creates a training review draft JSONL from an SFT export and raw generation output.

  Usage:

      mix procession.training.review_draft \\
        --phase qe7c \\
        --training-run smollm2_npc_lora_qe7c_memory_expression \\
        --eval-run qe7c_exact_rows_generate \\
        --eval-set qe7c_exact_rows \\
        --sft priv/training/exports/npc_interaction_qe7c_memory_expression_sft.jsonl \\
        --raw ~/procession-ai-training/qe7c_exact_rows_raw_generations.jsonl \\
        --out priv/training/reviews/npc_interaction_qe7c_exact_row_review_draft.jsonl

  The draft rows include empty rating, error_tags, and training_note fields for human review.
  """

  use Mix.Task

  @shortdoc "Creates a training review draft JSONL"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          phase: :string,
          training_run: :string,
          eval_run: :string,
          eval_set: :string,
          sft: :string,
          raw: :string,
          out: :string
        ],
        aliases: [
          s: :sft,
          r: :raw,
          o: :out
        ]
      )

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    phase = required!(opts, :phase)
    training_run = required!(opts, :training_run)
    eval_run = required!(opts, :eval_run)
    eval_set = required!(opts, :eval_set)
    sft_path = required!(opts, :sft)
    raw_path = required!(opts, :raw) |> Path.expand()
    out_path = required!(opts, :out)

    with {:ok, sft_rows_by_id} <- load_sft_rows_by_id(sft_path),
         {:ok, raw_rows} <- load_jsonl(raw_path),
         {:ok, review_rows} <-
           build_review_rows(raw_rows, sft_rows_by_id, %{
             "phase" => phase,
             "training_run" => training_run,
             "eval_run" => eval_run,
             "eval_set" => eval_set
           }),
         :ok <- write_jsonl(out_path, review_rows) do
      Mix.shell().info("Wrote #{length(review_rows)} review draft rows to #{out_path}")
    else
      {:error, reason} ->
        Mix.raise("Failed to create review draft: #{inspect(reason)}")
    end
  end

  defp required!(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> value
      :error -> Mix.raise("Missing required option: --#{String.replace(to_string(key), "_", "-")}")
    end
  end

  defp load_sft_rows_by_id(path) do
    with {:ok, rows} <- load_jsonl(path) do
      {:ok, Map.new(rows, fn row -> {row["id"], row} end)}
    end
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

  defp build_review_rows(raw_rows, sft_rows_by_id, run_context) do
    review_rows =
      Enum.map(raw_rows, fn raw ->
        id = raw["id"]
        sft = Map.fetch!(sft_rows_by_id, id)

        Map.merge(run_context, %{
          "id" => id,
          "expected" => Map.get(raw, "expected", sft["completion"]),
          "raw_generated" => raw["generated"],
          "rating" => "",
          "error_tags" => [],
          "training_note" => "",
          "metadata" => %{
            "category" => get_in(sft, ["metadata", "category"]),
            "delivery_style" => get_in(sft, ["metadata", "delivery_style"]),
            "conversational_move" => get_in(sft, ["metadata", "conversational_move"]),
            "recent_memory" => get_in(sft, ["metadata", "recent_memory"])
          }
        })
      end)

    {:ok, review_rows}
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
end
