defmodule Procession.EntityCapabilities do
  @moduledoc """
  First-pass capability rules for entity types.

  These rules intentionally use simple entity type checks for now. Future phases
  may replace or extend this with richer validated capability metadata.

  Command parsing, display formatting, AI boundaries, and gameplay orchestration
  should depend on this module instead of scattering type checks.
  """

  def inspectable?(%{type: type}) when type in [:npc, :player, :location, :faction], do: true
  def inspectable?(_entity), do: false

  def talkable?(%{type: :npc}), do: true
  def talkable?(_entity), do: false

  def askable?(%{type: :npc}), do: true
  def askable?(_entity), do: false

  def movable?(%{type: :player}), do: true
  def movable?(_entity), do: false

  def location?(%{type: :location}), do: true
  def location?(_entity), do: false

  def tickable?(%{type: :npc}), do: true
  def tickable?(_entity), do: false
end
