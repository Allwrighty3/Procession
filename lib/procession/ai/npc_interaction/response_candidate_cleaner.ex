defmodule Procession.AI.NPCInteraction.ResponseCandidateCleaner do
  @moduledoc """
  Cleans raw NPC response candidates before final intent validation.

  Expression models may produce a good first line followed by repeated text,
  prompt residue, or extra sections. This cleaner keeps the first usable NPC
  line/prefix and trims obvious continuation artifacts.

  This module does not call AI, mutate simulation state, execute gameplay
  behavior, or decide canon truth.
  """

  @stop_markers [
    "\n",
    "###",
    "Task:",
    "Context:",
    "Response:",
    "Constraints:",
    "Expected:",
    "Generated:"
  ]

  @doc """
  Cleans a raw candidate response.

  Returns a string when given a string. Non-strings are returned unchanged so
  upstream validation can still report invalid candidate types.
  """
  @spec clean(term()) :: term()
  def clean(candidate) when is_binary(candidate) do
    clean(candidate, %{})
  end

  def clean(candidate), do: candidate

  @doc """
  Cleans a raw candidate response using optional expression context.

  Supported expression context keys may be string or atom keys:

  - `delivery_style`
  - `conversational_move`

  Each may be either a string or a map containing `"shape"` / `"move"`.
  """
  @spec clean(term(), map() | keyword()) :: term()
  def clean(candidate, expression_context) when is_binary(candidate) do
    candidate
    |> String.trim()
    |> strip_wrapping_quotes()
    |> strip_speaker_label()
    |> trim_stop_markers()
    |> normalize_sentence_spacing()
    |> trim_repeated_sentences()
    |> trim_by_context(expression_context)
    |> trim_dangling_tail()
    |> String.trim()
  end

  def clean(candidate, _expression_context), do: candidate

  defp strip_wrapping_quotes(candidate) do
    candidate
    |> String.trim()
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"")
    |> String.trim_leading("“")
    |> String.trim_trailing("”")
    |> String.trim()
  end

  defp strip_speaker_label(candidate) do
    String.replace(candidate, ~r/^[A-Z][A-Za-z0-9 _-]{0,40}:\s*/, "")
  end

  defp trim_stop_markers(candidate) do
    Enum.reduce_while(@stop_markers, candidate, fn marker, acc ->
      case String.split(acc, marker, parts: 2) do
        [before_marker, _after_marker] -> {:halt, String.trim(before_marker)}
        [unchanged] -> {:cont, unchanged}
      end
    end)
  end

  defp normalize_sentence_spacing(candidate) do
    String.replace(candidate, ~r/([.!?])([A-Z])/, "\\1 \\2")
  end

  defp trim_repeated_sentences(candidate) do
    units = sentence_units(candidate)

    case units do
      [] ->
        candidate

      [_one] ->
        candidate

      _many ->
        trim_repeated_tail_units(units, candidate)
    end
  end

  defp trim_repeated_tail_units(units, original_candidate) do
    [last | rest_reversed] = Enum.reverse(units)
    previous = List.first(rest_reversed)

    if normalize_for_comparison(last) == normalize_for_comparison(previous) do
      units
      |> Enum.drop(-1)
      |> Enum.join(" ")
    else
      original_candidate
    end
  end

  defp trim_by_context(candidate, expression_context) do
    delivery_shape = context_value(expression_context, "delivery_style", "shape")
    conversational_move = context_value(expression_context, "conversational_move", "move")

    cond do
      is_nil(delivery_shape) and is_nil(conversational_move) ->
        keep_sentence_units(candidate, 3)

      delivery_shape in ["terse", "flat"] ->
        keep_sentence_units(candidate, 1)

      conversational_move in ["answer_only", "refuse", "challenge_premise"] ->
        keep_sentence_units(candidate, 2)

      conversational_move in ["answer_and_warn", "answer_and_challenge"] ->
        keep_sentence_units(candidate, 2)

      conversational_move in ["ask_followup", "answer_and_question"] ->
        keep_sentence_units(candidate, 2)

      true ->
        keep_sentence_units(candidate, 2)
    end
  end

  defp keep_sentence_units(candidate, max_units) do
    units = sentence_units(candidate)

    cond do
      units == [] ->
        candidate

      length(units) <= max_units ->
        candidate

      true ->
        units
        |> Enum.take(max_units)
        |> Enum.join(" ")
    end
  end

  defp trim_dangling_tail(candidate) do
    trimmed = String.trim(candidate)

    cond do
      trimmed == "" ->
        ""

      Regex.match?(~r/[.!?]$/, trimmed) ->
        trimmed

      true ->
        case sentence_units(trimmed) do
          [] -> trimmed
          units -> Enum.join(units, " ")
        end
    end
  end

  defp sentence_units(candidate) do
    ~r/[^.!?]+[.!?]/
    |> Regex.scan(candidate)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_for_comparison(sentence) do
    sentence
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "")
  end

  defp context_value(context, top_key, nested_key) when is_list(context) do
    top_key
    |> String.to_existing_atom()
    |> then(&Keyword.get(context, &1, %{}))
    |> nested_context_value(nested_key)
  rescue
    ArgumentError -> nil
  end

  defp context_value(context, top_key, nested_key) when is_map(context) do
    context
    |> Map.get(top_key, Map.get(context, safe_existing_atom(top_key), %{}))
    |> nested_context_value(nested_key)
  end

  defp context_value(_context, _top_key, _nested_key), do: nil

  defp nested_context_value(value, _nested_key) when is_binary(value), do: value

  defp nested_context_value(value, nested_key) when is_map(value) do
    Map.get(value, nested_key, Map.get(value, safe_existing_atom(nested_key)))
  end

  defp nested_context_value(_value, _nested_key), do: nil

  defp safe_existing_atom(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> nil
  end
end
