defmodule Procession.AI.NPCInteraction.ResponseCandidateCleaner do
  @moduledoc """
  Cleans raw NPC response candidates before final intent validation.

  Expression models may produce a good first line followed by repeated text,
  prompt residue, or extra sections. This cleaner keeps the first usable NPC
  line and trims obvious continuation artifacts.

  This module does not call AI, mutate simulation state, or execute gameplay
  behavior.
  """

  @stop_markers [
    "\n",
    "###",
    "Task:",
    "Context:",
    "Response:",
    "Constraints:"
  ]

  @doc """
  Cleans a raw candidate response.

  Returns a string when given a string. Non-strings are returned unchanged so
  upstream validation can still report invalid candidate types.
  """
  @spec clean(term()) :: term()
  def clean(candidate) when is_binary(candidate) do
    candidate
    |> String.trim()
    |> trim_stop_markers()
    |> trim_repeated_sentences()
    |> String.trim()
  end

  def clean(candidate), do: candidate

  defp trim_stop_markers(candidate) do
    Enum.reduce(@stop_markers, candidate, fn marker, acc ->
      case String.split(acc, marker, parts: 2) do
        [before_marker, _after_marker] -> String.trim(before_marker)
        [unchanged] -> unchanged
      end
    end)
  end

  defp trim_repeated_sentences(candidate) do
    sentences = String.split(candidate, ". ", trim: true)

    if length(sentences) > 2 do
      sentences
      |> Enum.take(2)
      |> Enum.join(". ")
      |> ensure_terminal_punctuation()
    else
      candidate
    end
  end

  defp ensure_terminal_punctuation(candidate) do
    if Regex.match?(~r/[.!?]$/, candidate) do
      candidate
    else
      candidate <> "."
    end
  end
end
