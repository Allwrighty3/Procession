# lib/procession/memory.ex
defmodule Procession.Memory do
  @moduledoc """
  Helpers for managing entity memory.

  For now this only handles short-term memory.
  Medium and long-term memory can be added later.
  """

  def remember_short(short_memory, message, limit \\ 10) do
    [message | short_memory]
    |> Enum.take(limit)
  end

  def remember_short_with_overflow(short_memory, message, limit \\ 10) do
    updated = [message | short_memory]

    {
      Enum.take(updated, limit),
      Enum.drop(updated, limit)
    }
  end

  def remember_medium(medium_memory, message, limit \\ 50) do
    [message | medium_memory]
    |> Enum.take(limit)
  end

  def remember_medium_with_overflow(medium_memory, message, limit \\ 50) do
    updated = [message | medium_memory]

    {
      Enum.take(updated, limit),
      Enum.drop(updated, limit)
    }
  end

  def remember_long(long_memory, message, limit \\ 200) do
    [message | long_memory]
    |> Enum.take(limit)
  end

  def flatten(state) do
    state.short_memory ++ state.medium_memory ++ state.long_memory
  end

  def search(memories, query) when is_binary(query) do
    normalized_query = String.downcase(query)

    Enum.filter(memories, fn memory ->
      memory
      |> Map.get(:content, "")
      |> to_string()
      |> String.downcase()
      |> String.contains?(normalized_query)
    end)
  end

  def new_entry(content, attrs \\ %{}) do
    %{
      content: content,
      type: Map.get(attrs, :type, :event),
      importance: Map.get(attrs, :importance, 1),
      timestamp: Map.get(attrs, :timestamp, DateTime.utc_now())
    }
  end

  def from_message(message) when is_map(message) do
    content = Map.get(message, :content, "")

    new_entry(content, %{
      type: Map.get(message, :type, :message),
      importance: Map.get(message, :importance, 1),
      timestamp: Map.get(message, :timestamp, DateTime.utc_now())
    })
    |> Map.put(:from, Map.get(message, :from))
  end
end
