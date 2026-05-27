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
end
