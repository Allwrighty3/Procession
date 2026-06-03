defmodule Procession.AI.NPCInteraction.VoiceExpressionExampleLoader do
  @moduledoc """
  Loads NPC interaction voice expression training examples.

  Voice expression examples train the model to express the same validated
  meaning in different character voices and subjective relationship stances.
  They are non-authoritative style data, not simulation truth.
  """

  @default_path "priv/training/npc_interaction_voice_expression_examples.jsonl"

  @type example :: map()
  @type load_result :: {:ok, [example()]} | {:error, term()}

  @spec load_default() :: load_result()
  def load_default do
    load(@default_path)
  end

  @spec load(Path.t()) :: load_result()
  def load(path) when is_binary(path) do
    with {:ok, contents} <- File.read(path) do
      contents
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reject(fn {line, _line_number} -> String.trim(line) == "" end)
      |> decode_lines()
    end
  end

  def load(_path), do: {:error, :invalid_voice_expression_example_path}

  defp decode_lines(lines) do
    lines
    |> Enum.reduce_while({:ok, []}, fn {line, line_number}, {:ok, examples} ->
      case Jason.decode(line) do
        {:ok, decoded} ->
          {:cont, {:ok, [decoded | examples]}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_jsonl_line, line_number, reason}}}
      end
    end)
    |> case do
      {:ok, examples} -> {:ok, Enum.reverse(examples)}
      error -> error
    end
  end
end
