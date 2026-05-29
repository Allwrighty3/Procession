# lib/procession/memory.ex
defmodule Procession.Memory do
  @moduledoc """
  Hierarchical memory utilities for Procession entities.

  Handles memory entry creation, short/medium/long memory promotion, flattening,
  ordering, and keyword search.
  """

  alias Procession.Memory.Entry

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

  def filter_by_type(memories, type) do
    Enum.filter(memories, fn memory ->
      Map.get(memory, :type) == type
    end)
  end

  def recent(memories, count) do
    Enum.take(memories, count)
  end

  def important(memories, minimum_importance) do
    Enum.filter(memories, fn memory ->
      Map.get(memory, :importance, 1) >= minimum_importance
    end)
  end

  def filter_by_sender(memories, sender) do
    Enum.filter(memories, fn memory ->
      Map.get(memory, :from) == sender
    end)
  end

  def filter_by_tag(memories, tag) do
    Enum.filter(memories, fn memory ->
      memory
      |> Map.get(:tags, [])
      |> Enum.member?(tag)
    end)
  end

  def new_entry(content, attrs \\ %{}) do
    %Entry{
      id: Map.get(attrs, :id, Procession.Id.memory()),
      content: content,
      type: Map.get(attrs, :type, :event),
      importance: Map.get(attrs, :importance, 1),
      timestamp: Map.get(attrs, :timestamp, DateTime.utc_now()),
      tags: Map.get(attrs, :tags, []),
      metadata: Map.get(attrs, :metadata, %{})
    }
  end

  def filter_by_metadata(memories, key, value) do
    Enum.filter(memories, fn memory ->
      memory
      |> Map.get(:metadata, %{})
      |> Map.get(key)
      |> matches_metadata_value?(value)
    end)
  end

  defp matches_metadata_value?(actual, expected) when is_list(actual) do
    expected in actual
  end

  defp matches_metadata_value?(actual, expected) do
    actual == expected
  end

  def from_message(message) when is_map(message) do
    content = Map.get(message, :content, "")

    attrs = %{
      type: Map.get(message, :type, :message),
      importance: Map.get(message, :importance, 1),
      timestamp: Map.get(message, :timestamp, DateTime.utc_now()),
      tags: Map.get(message, :tags, []),
      metadata: Map.get(message, :metadata, %{})
    }

    attrs =
      case Map.fetch(message, :id) do
        {:ok, id} when not is_nil(id) -> Map.put(attrs, :id, id)
        _ -> attrs
      end

    %Entry{new_entry(content, attrs) | from: Map.get(message, :from)}
  end
end
