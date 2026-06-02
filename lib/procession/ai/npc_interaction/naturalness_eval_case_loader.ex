defmodule Procession.AI.NPCInteraction.NaturalnessEvalCaseLoader do
  @moduledoc """
  Loads NPC interaction naturalness eval cases from JSONL files.

  Naturalness eval cases are inert data. Loading them does not call AI,
  mutate simulation state, or execute gameplay behavior.
  """

  @default_path "priv/evals/npc_interaction_naturalness_cases.jsonl"

  @type eval_case :: map()
  @type load_result :: {:ok, [eval_case()]} | {:error, term()}

  @doc """
  Loads the default NPC interaction naturalness eval case file.
  """
  @spec load_default() :: load_result()
  def load_default do
    load(@default_path)
  end

  @doc """
  Loads naturalness eval cases from a JSONL file.

  Blank lines are ignored.
  """
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

  def load(_path), do: {:error, :invalid_naturalness_eval_case_path}

  defp decode_lines(lines) do
    lines
    |> Enum.reduce_while({:ok, []}, fn {line, line_number}, {:ok, cases} ->
      case Jason.decode(line) do
        {:ok, decoded} ->
          {:cont, {:ok, [decoded | cases]}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_jsonl_line, line_number, reason}}}
      end
    end)
    |> case do
      {:ok, cases} -> {:ok, Enum.reverse(cases)}
      error -> error
    end
  end
end
