defmodule Procession.Memory.Entry do
  @moduledoc """
  A structured memory entry stored by an entity.

  Memory entries are created from messages and store in short, medium,
  and long-term memory layers.
  """

  defstruct [
    :id,
    :content,
    :type,
    :importance,
    :timestamp,
    :from,
    tags: [],
    metadata: %{}
  ]
end
