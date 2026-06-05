defmodule Mix.Tasks.Procession.Training.AutoReview do
  @moduledoc """
  Creates an automatic training review JSONL from an SFT export and raw generation output.

  This task is intentionally heuristic. It does not replace human judgment.
  It pre-tags obvious training failures so humans can review the review instead
  of manually labeling every row.

  Usage:

      mix procession.training.auto_review \\
        --phase qe7c \\
        --training-run smollm2_npc_lora_qe7c_memory_expression \\
        --eval-run qe7c_exact_rows_generate \\
        --eval-set qe7c_exact_rows \\
        --sft priv/training/exports/npc_interaction_qe7c_memory_expression_sft.jsonl \\
        --raw ~/procession-ai-training/qe7c_exact_rows_raw_generations.jsonl \\
        --out priv/training/reviews/npc_interaction_qe7c_exact_row_auto_review.jsonl
  """

  use Mix.Task

  @shortdoc "Auto-tags training review rows from raw generations"

  @metadata_label_patterns [
    "withhold and question",
    "withhold_and_question",
    "answer only",
    "answer_only",
    "reference_policy",
    "stance_effect",
    "do_not_reference",
    "conversational_move"
  ]

  @catchphrase_patterns [
    "that's about all i can say today"
  ]

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
      Mix.shell().info("Wrote #{length(review_rows)} auto-review rows to #{out_path}")
      print_summary(review_rows)
    else
      {:error, reason} ->
        Mix.raise("Failed to create auto-review: #{inspect(reason)}")
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

        expected = Map.get(raw, "expected", sft["completion"])
        raw_generated = Map.get(raw, "generated", "")

        metadata = %{
          "category" => get_in(sft, ["metadata", "category"]),
          "delivery_style" => get_in(sft, ["metadata", "delivery_style"]),
          "conversational_move" => get_in(sft, ["metadata", "conversational_move"]),
          "recent_memory" => get_in(sft, ["metadata", "recent_memory"])
        }

        auto = classify(expected, raw_generated, metadata)

        Map.merge(run_context, %{
          "id" => id,
          "expected" => expected,
          "raw_generated" => raw_generated,
          "rating" => auto.rating,
          "error_tags" => auto.error_tags,
          "confidence" => auto.confidence,
          "needs_human_review" => auto.needs_human_review,
          "auto_review_notes" => auto.notes,
          "training_note" => auto.training_note,
          "metadata" => metadata
        })
      end)

    {:ok, review_rows}
  rescue
    reason -> {:error, reason}
  end

  defp classify(expected, raw_generated, metadata) do
    normalized_expected = normalize(expected)
    normalized_raw = normalize(raw_generated)

    tags_and_notes =
      []
      |> maybe_add_exact_match(normalized_expected, normalized_raw)
      |> maybe_add_metadata_label_leak(normalized_raw)
      |> maybe_add_catchphrase_tail(normalized_raw)
      |> maybe_add_followup_not_allowed(raw_generated, metadata)
      |> maybe_add_over_disclosure(expected, raw_generated, metadata)
      |> maybe_add_duplicate_fact(raw_generated)
      |> maybe_add_memory_policy_violation(raw_generated, metadata)

    tags =
      tags_and_notes
      |> Enum.flat_map(fn {tag, _note} -> if tag == :pass, do: [], else: [to_string(tag)] end)
      |> Enum.uniq()

    notes =
      tags_and_notes
      |> Enum.map(fn {_tag, note} -> note end)
      |> Enum.uniq()

    rating = rating_for(tags, normalized_expected, normalized_raw)
    confidence = confidence_for(tags, normalized_expected, normalized_raw)

    %{
      rating: rating,
      error_tags: tags,
      confidence: confidence,
      needs_human_review: rating != "pass" or confidence != "high",
      notes: notes,
      training_note: training_note_for(tags, metadata)
    }
  end

  defp maybe_add_exact_match(items, expected, raw) do
    if expected == raw do
      [{:pass, "Raw output exactly matches expected output."} | items]
    else
      items
    end
  end

  defp maybe_add_metadata_label_leak(items, raw) do
    if Enum.any?(@metadata_label_patterns, &String.contains?(raw, &1)) do
      [
        {:metadata_label_leak, "Raw output appears to include internal labels or metadata terms."}
        | items
      ]
    else
      items
    end
  end

  defp maybe_add_catchphrase_tail(items, raw) do
    if Enum.any?(@catchphrase_patterns, &String.contains?(raw, &1)) do
      [{:catchphrase_tail, "Raw output includes an overused catchphrase tail."} | items]
    else
      items
    end
  end

  defp maybe_add_followup_not_allowed(items, raw_generated, metadata) do
    move = get_in(metadata, ["conversational_move", "move"])
    detail_level = get_in(metadata, ["delivery_style", "detail_level"])

    followup_not_allowed? =
      String.contains?(raw_generated, "?") and
        (move in ["answer_only", "name_only"] or detail_level == "minimal")

    if followup_not_allowed? do
      [
        {:followup_not_allowed,
         "Raw output adds a question where move/detail suggests no follow-up."}
        | items
      ]
    else
      items
    end
  end

  defp maybe_add_over_disclosure(items, expected, raw_generated, metadata) do
    move = get_in(metadata, ["conversational_move", "move"])
    detail_level = get_in(metadata, ["delivery_style", "detail_level"])

    expected_sentence_count = sentence_count(expected)
    raw_sentence_count = sentence_count(raw_generated)

    over_disclosed? =
      (move == "name_only" or detail_level == "minimal") and
        raw_sentence_count > expected_sentence_count

    if over_disclosed? do
      [
        {:over_disclosure, "Raw output provides more detail than expected for move/detail level."}
        | items
      ]
    else
      items
    end
  end

  defp maybe_add_duplicate_fact(items, raw_generated) do
    sentences =
      raw_generated
      |> split_sentences()
      |> Enum.map(&normalize/1)
      |> Enum.reject(&(&1 == ""))

    duplicate? = Enum.uniq(sentences) != sentences

    if duplicate? do
      [{:duplicate_fact, "Raw output repeats the same sentence or proposition."} | items]
    else
      items
    end
  end

  defp maybe_add_memory_policy_violation(items, raw_generated, metadata) do
    recent_memory = Map.get(metadata, "recent_memory") || %{}
    reference_policy = recent_memory["reference_policy"]
    relevance = recent_memory["relevance"]
    summary = recent_memory["summary"]

    forbidden_reference? = reference_policy == "do_not_reference" or relevance == "irrelevant"

    if forbidden_reference? and memory_summary_overlap?(raw_generated, summary) do
      [
        {:memory_policy_violation,
         "Raw output appears to mention memory that should not be referenced."}
        | items
      ]
    else
      items
    end
  end

  defp memory_summary_overlap?(_raw_generated, summary) when summary in [nil, ""], do: false

  defp memory_summary_overlap?(raw_generated, summary) do
    raw_words = significant_words(raw_generated) |> MapSet.new()
    summary_words = significant_words(summary)

    summary_words
    |> Enum.count(&MapSet.member?(raw_words, &1))
    |> Kernel.>=(2)
  end

  defp significant_words(text) do
    text
    |> normalize()
    |> String.replace(~r/[^a-z0-9\s]/, " ")
    |> String.split()
    |> Enum.reject(&(String.length(&1) < 4))
    |> Enum.reject(&(&1 in stop_words()))
  end

  defp stop_words do
    [
      "that",
      "this",
      "with",
      "from",
      "earlier",
      "listener",
      "player",
      "about",
      "asking",
      "asked",
      "they",
      "them",
      "their",
      "there",
      "what",
      "when",
      "where",
      "would",
      "could",
      "should"
    ]
  end

  defp rating_for(tags, expected, raw) do
    cond do
      tags == [] and expected == raw ->
        "pass"

      "metadata_label_leak" in tags or "memory_policy_violation" in tags ->
        "reject"

      tags == [] ->
        "minor"

      true ->
        "fail"
    end
  end

  defp confidence_for(tags, expected, raw) do
    cond do
      tags == [] and expected == raw ->
        "high"

      "metadata_label_leak" in tags or "catchphrase_tail" in tags ->
        "high"

      tags == [] ->
        "low"

      true ->
        "medium"
    end
  end

  defp training_note_for(tags, metadata) do
    move = get_in(metadata, ["conversational_move", "move"])
    detail_level = get_in(metadata, ["delivery_style", "detail_level"])

    cond do
      "memory_policy_violation" in tags ->
        "Reinforce that do_not_reference or irrelevant memory must not appear in final dialogue."

      "metadata_label_leak" in tags ->
        "Reinforce that internal control labels and metadata terms must never be spoken."

      "over_disclosure" in tags ->
        "Reinforce that #{inspect(move)} with #{inspect(detail_level)} detail should not add unsupported extra detail."

      "catchphrase_tail" in tags ->
        "Add varied alternatives and reduce reliance on repeated stock emotional tails."

      "followup_not_allowed" in tags ->
        "Reinforce that #{inspect(move)} should not add follow-up questions unless the move supports them."

      true ->
        ""
    end
  end

  defp sentence_count(text), do: length(split_sentences(text))

  defp split_sentences(text) do
    Regex.scan(~r/[^.!?]+[.!?]/, text)
    |> Enum.map(fn [sentence] -> String.trim(sentence) end)
  end

  defp normalize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
  end

  defp normalize(_), do: ""

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

  defp print_summary(rows) do
    rating_counts = Enum.frequencies_by(rows, & &1["rating"])
    tag_counts = rows |> Enum.flat_map(& &1["error_tags"]) |> Enum.frequencies()

    Mix.shell().info("")
    Mix.shell().info("Ratings:")
    print_counts(rating_counts)

    Mix.shell().info("")
    Mix.shell().info("Error tags:")
    print_counts(tag_counts)
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
