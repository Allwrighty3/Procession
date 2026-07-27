defmodule Procession.PlayerPhysical do
  @moduledoc """
  Low-level player physical-action boundary for Living Briar sessions.

  Commands describe only primitive bodily or material consequences. They do not encode
  social intent, ownership, occupations, trade, assistance, or hostility.
  """

  alias Procession.LivingGameSession

  @directions [:north, :south, :east, :west]
  @primitives [
    :contact_loose_raw,
    :manipulate_held_raw,
    :consume_held_usable
  ]

  def move(session, direction) when direction in @directions,
    do: LivingGameSession.physical_action(session, :move, direction: direction)

  def move(_session, _direction), do: {:error, :invalid_direction}

  def perform(session, primitive) when primitive in @primitives,
    do: LivingGameSession.physical_action(session, primitive)

  def perform(_session, _primitive), do: {:error, :invalid_player_primitive}

  def contact(session, target_id) when is_binary(target_id),
    do: LivingGameSession.physical_action(session, :contact_body, target_id: target_id)

  def contact(_session, _target_id), do: {:error, :unknown_regional_body}
end
