defmodule Procession.AI.MemoryContext do
  @moduledoc """
  Selects deterministic memory context for AI requests.

  This module does not call an AI model and does not summarize memories.
  It simply chooses a small, predictable set of memories that can be passed
  into prompt builders.
  """

  @default_recent_count 5
  @default_minimum_importance 4

  def select(memories, opts \\ [])

  def select(memories, opts) when is_list(memories) do
    recent_count = Keyword.get(opts, :recent_count, @default_recent_count)
    minimum_importance = Keyword.get(opts, :minimum_importance, @default_minimum_importance)

    recent_memories = Enum.take(memories, recent_count)

    importance_memories =
      Enum.filter(memories, fn memory ->
        Map.get(memory, :importance, 1) >= minimum_importance
      end)

    (recent_memories ++ importance_memories)
    |> Enum.uniq_by(&memory_key/1)
  end

  def select(_memories, _opts) do
    []
  end

  defp memory_key(memory) do
    Map.get(memory, :id, memory)
  end
end
