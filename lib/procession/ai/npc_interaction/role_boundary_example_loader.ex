defmodule Procession.AI.NPCInteraction.RoleBoundaryExampleLoader do
  @moduledoc """
  Loads NPC interaction role-boundary training examples.

  These examples are non-authoritative training data intended to reduce role,
  location, relationship, and current-activity smearing during model training.
  """

  @default_path "priv/training/npc_interaction_role_boundary_examples.jsonl"

  @type example :: map()
  @type load_result :: {:ok, [example()]} | {:error, term()}

  @doc """
  Loads the default role-boundary example file.
  """
  @spec load_default() :: load_result()
  def load_default do
    load(@default_path)
  end

  @doc """
  Loads role-boundary examples from a JSONL file.

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

  def load(_path), do: {:error, :invalid_role_boundary_example_path}

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
