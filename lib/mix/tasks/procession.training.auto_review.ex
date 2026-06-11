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

  @followup_forbidden_moves [
    "answer_only",
    "name_only"
  ]

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
    "that's about all i can say today",
    "why are you asking"
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
      {:ok, Map.new(rows, fn row -> {canonical_id(row["id"]), row} end)}
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
        raw_id = raw["id"]
        canonical_raw_id = canonical_id(raw_id)

        sft =
          case Map.fetch(sft_rows_by_id, canonical_raw_id) do
            {:ok, sft} ->
              sft

            :error ->
              raise ArgumentError,
                    "No SFT row found for raw id #{inspect(raw_id)} " <>
                      "(canonical id #{inspect(canonical_raw_id)})"
          end

        id = sft["id"] || raw_id
        expected = Map.get(raw, "expected", sft["completion"])
        raw_generated = Map.get(raw, "generated", "")

        prompt_context = extract_prompt_expression_context(sft["prompt"])

        metadata = %{
          "category" => get_in(sft, ["metadata", "category"]),
          "voice_profile" =>
            get_in(sft, ["metadata", "voice_profile"]) || Map.get(prompt_context, "voice_profile"),
          "relationship_stance" =>
            get_in(sft, ["metadata", "relationship_stance"]) ||
              Map.get(prompt_context, "relationship_stance"),
          "emotional_state" =>
            get_in(sft, ["metadata", "emotional_state"]) ||
              Map.get(prompt_context, "emotional_state"),
          "delivery_style" =>
            get_in(sft, ["metadata", "delivery_style"]) ||
              Map.get(prompt_context, "delivery_style"),
          "conversational_move" =>
            get_in(sft, ["metadata", "conversational_move"]) ||
              Map.get(prompt_context, "conversational_move"),
          "recent_memory" =>
            get_in(sft, ["metadata", "recent_memory"]) || Map.get(prompt_context, "recent_memory")
        }

        auto = classify(expected, raw_generated, metadata)

        Map.merge(run_context, %{
          "id" => id,
          "raw_id" => raw_id,
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

    if normalized_expected == normalized_raw do
      %{
        rating: "pass",
        error_tags: [],
        confidence: "high",
        needs_human_review: false,
        notes: ["Raw output exactly matches expected output."],
        training_note: ""
      }
    else
      tags_and_notes =
        []
        |> maybe_add_metadata_label_leak(normalized_raw)
        |> maybe_add_catchphrase(normalized_raw)
        |> maybe_add_followup_not_allowed(expected, raw_generated, metadata)
        |> maybe_add_response_shape_issues(expected, raw_generated, metadata)
        |> maybe_add_audience_mismatch(raw_generated, metadata)
        |> maybe_add_tone_mismatch(raw_generated, metadata)
        |> maybe_add_duplicate_fact(raw_generated)
        |> maybe_add_memory_policy_violation(raw_generated, metadata)

      tags =
        tags_and_notes
        |> Enum.map(fn {tag, _note} -> to_string(tag) end)
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

  defp maybe_add_catchphrase(items, raw) do
    if Enum.any?(@catchphrase_patterns, &String.contains?(raw, &1)) do
      [{:catchphrase, "Raw output includes an overused catchphrase."} | items]
    else
      items
    end
  end

  defp maybe_add_followup_not_allowed(items, expected, raw_generated, metadata) do
    move = get_in(metadata, ["conversational_move", "move"])

    raw_has_question? = String.contains?(raw_generated || "", "?")
    expected_has_question? = String.contains?(expected || "", "?")

    followup_not_allowed? =
      raw_has_question? and
        not expected_has_question? and
        move in @followup_forbidden_moves

    if followup_not_allowed? do
      [
        {:followup_not_allowed,
         "Raw output adds a question where the conversational move and expected response do not support a follow-up."}
        | items
      ]
    else
      items
    end
  end

  defp maybe_add_response_shape_issues(items, expected, raw_generated, metadata) do
    move = get_in(metadata, ["conversational_move", "move"])
    detail_level = get_in(metadata, ["delivery_style", "detail_level"])

    expected_sentence_count = sentence_count(expected)
    raw_sentence_count = sentence_count(raw_generated)

    extra_sentences? = raw_sentence_count > expected_sentence_count
    strict_shape? = move in ["name_only", "answer_only"] or detail_level == "minimal"

    cond do
      not extra_sentences? ->
        items

      contains_substantive_extra_detail?(expected, raw_generated, metadata) ->
        [
          {:over_disclosure,
           "Raw output adds substantive identity, role, location, relationship, memory, or world-state detail beyond the expected response."}
          | items
        ]

      strict_shape? ->
        [
          {:unnecessary_continuation,
           "Raw output continues after the requested response shape appears complete."}
          | items
        ]

      true ->
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

  defp maybe_add_audience_mismatch(items, raw_generated, metadata) do
    listener = get_in(metadata, ["relationship_stance", "listener"]) || %{}
    listener_role = listener["role"]
    listener_trust = listener["trust"]
    listener_attitude = listener["attitude"]

    raw = normalize(raw_generated)

    child_listener? =
      listener_role in ["child", "young_child"] or
        listener_attitude in ["child", "gentle"]

    scary_listener? =
      listener_role in ["scary_stranger", "threatening_stranger", "suspicious_stranger"]

    friend_listener? = listener_role in ["friend", "trusted_friend"] or listener_trust == "high"

    customer_listener? = listener_role in ["customer", "paying_guest", "patient"]

    authority_listener? =
      listener_role in ["authority", "authority_figure", "guard", "reeve", "captain"]

    mismatch? =
      (child_listener? and suspicious_or_formal_challenge?(raw)) or
        (friend_listener? and formal_challenge?(raw)) or
        (customer_listener? and hostile_challenge?(raw)) or
        (authority_listener? and overly_familiar?(raw)) or
        (scary_listener? and overly_warm_or_curious?(raw))

    if mismatch? do
      [
        {:audience_mismatch,
         "Raw output appears socially mismatched for the listener role, trust level, or relationship."}
        | items
      ]
    else
      items
    end
  end

  defp maybe_add_tone_mismatch(items, raw_generated, metadata) do
    emotional_state = get_in(metadata, ["emotional_state"]) || %{}
    voice_profile = get_in(metadata, ["voice_profile"]) || %{}
    listener = get_in(metadata, ["relationship_stance", "listener"]) || %{}

    mood = emotional_state["mood"]
    voice_style = normalize(voice_profile["style"] || "")
    voice_baseline = normalize(voice_profile["baseline"] || "")
    listener_trust = listener["trust"]

    raw = normalize(raw_generated)

    mismatch? =
      (mood in ["warm", "welcoming", "calm", "gentle"] and suspicious_or_formal_challenge?(raw)) or
        (mood in ["warm", "welcoming", "calm"] and hostile_challenge?(raw)) or
        (mood in ["professional", "controlled"] and childish_or_overexcited?(raw)) or
        (mood in ["afraid", "scared"] and overly_social?(raw)) or
        (mood in ["protective", "guarded", "suspicious", "hostile"] and overly_apologetic?(raw)) or
        (listener_trust == "high" and formal_challenge?(raw)) or
        (String.contains?(voice_style <> " " <> voice_baseline, "formal") and
           childish_or_overexcited?(raw))

    if mismatch? do
      [
        {:tone_mismatch,
         "Raw output appears emotionally mismatched for the voice profile, relationship stance, or emotional state."}
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

      "metadata_label_leak" in tags or "catchphrase" in tags ->
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

      "catchphrase" in tags ->
        "Add varied alternatives and reduce reliance on repeated stock emotional tails."

      "followup_not_allowed" in tags ->
        "Reinforce that #{inspect(move)} should not add follow-up questions unless the move supports them."

      "unnecessary_continuation" in tags ->
        "Reinforce that a complete answer should stop instead of adding unsupported chatter, apology, or extra tail."

      "audience_mismatch" in tags ->
        "Reinforce that phrasing should fit the listener role, trust level, familiarity, and social position."

      "tone_mismatch" in tags ->
        "Reinforce that emotional tone should match the voice profile, relationship stance, emotional state, and memory stance effect."

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

  defp contains_substantive_extra_detail?(expected, raw_generated, metadata) do
    extra_text = extra_text_after_expected(expected, raw_generated)

    text_to_check =
      if extra_text == "" do
        raw_generated
      else
        extra_text
      end

    contains_role_or_location_detail?(text_to_check) or
      contains_memory_overlap?(text_to_check, metadata)
  end

  defp extra_text_after_expected(expected, raw_generated) do
    normalized_expected = String.trim(expected || "")

    if normalized_expected != "" and String.starts_with?(raw_generated, normalized_expected) do
      raw_generated
      |> String.replace_prefix(normalized_expected, "")
      |> String.trim()
    else
      ""
    end
  end

  defp contains_role_or_location_detail?(text) do
    normalized = normalize(text)

    Enum.any?(
      [
        "inn",
        "innkeeper",
        "merchant",
        "crossroads",
        "blacksmith",
        "forge",
        "cartographer",
        "windmere",
        "shepherd",
        "moss vale",
        "hunter",
        "pinewatch",
        "guard",
        "gatehouse",
        "healer",
        "northwell",
        "mason",
        "alderford",
        "locksmith",
        "copperbend",
        "candlemaker",
        "ember hollow",
        "beekeeper",
        "clover rise",
        "glassblower",
        "bright quay",
        "baker",
        "stonebridge",
        "midwife",
        "larkspur"
      ],
      &String.contains?(normalized, &1)
    )
  end

  defp contains_memory_overlap?(text, metadata) do
    recent_memory = Map.get(metadata, "recent_memory") || %{}
    memory_summary_overlap?(text, recent_memory["summary"])
  end

  defp canonical_id(id) when is_binary(id) do
    String.replace(id, ~r/^(review_reinforcement_)+/, "")
  end

  defp canonical_id(id), do: id

  defp extract_prompt_expression_context(prompt) when is_binary(prompt) do
    case Regex.run(
           ~r/### Expression Context\s*\n(?<json>\{.*?\})\s*\n\n### Deterministic Fallback/s,
           prompt,
           capture: ["json"]
         ) do
      [json] ->
        case Jason.decode(json) do
          {:ok, context} -> context
          {:error, _reason} -> %{}
        end

      _ ->
        %{}
    end
  end

  defp extract_prompt_expression_context(_prompt), do: %{}

  defp suspicious_or_formal_challenge?(raw) do
    String.contains?(raw, "why are you asking") or
      String.contains?(raw, "why do you ask") or
      String.contains?(raw, "state your business") or
      String.contains?(raw, "answer me") or
      String.contains?(raw, "state that again")
  end

  defp formal_challenge?(raw) do
    String.contains?(raw, "state your business") or
      String.contains?(raw, "state your name") or
      String.contains?(raw, "answer me")
  end

  defp hostile_challenge?(raw) do
    String.contains?(raw, "get lost") or
      String.contains?(raw, "state your business") or
      String.contains?(raw, "leave it alone")
  end

  defp overly_familiar?(raw) do
    String.contains?(raw, "dear") or
      String.contains?(raw, "little one")
  end

  defp overly_warm_or_curious?(raw) do
    String.contains?(raw, "is she nice") or
      String.contains?(raw, "are you lost") or
      String.contains?(raw, "welcome")
  end

  defp childish_or_overexcited?(raw) do
    String.contains?(raw, "i don't know!") or
      String.contains?(raw, "is she nice") or
      String.contains?(raw, "does she have a sword") or
      String.contains?(raw, "is she scary")
  end

  defp overly_social?(raw) do
    String.contains?(raw, "why are you asking") or
      String.contains?(raw, "are you lost") or
      String.contains?(raw, "what can i do for you")
  end

  defp overly_apologetic?(raw) do
    String.contains?(raw, "sorry") or
      String.contains?(raw, "forgive me")
  end
end
