defmodule Procession.PlayerPhysical do
  @moduledoc """
  Low-level player physical-action boundary for Living Briar sessions.

  Gathering and held-material manipulation begin persistent physical processes. They receive one
  opportunity per world tick until the underlying physical condition prevents further progress or
  the player interrupts them. Movement, consumption, and body contact remain immediate primitives.
  """

  alias Procession.LivingGameSession

  @directions [:north, :south, :east, :west]
  @persistent_primitives [:contact_loose_raw, :manipulate_held_raw]

  def move(session, direction) when direction in @directions,
    do: LivingGameSession.physical_action(session, :move, direction: direction)

  def move(_session, _direction), do: {:error, :invalid_direction}

  def perform(session, primitive) when primitive in @persistent_primitives,
    do: LivingGameSession.begin_physical_action(session, primitive)

  def perform(session, :consume_held_usable),
    do: LivingGameSession.physical_action(session, :consume_held_usable)

  def perform(_session, _primitive), do: {:error, :invalid_player_primitive}

  def contact(session, target_id) when is_binary(target_id),
    do: LivingGameSession.physical_action(session, :contact_body, target_id: target_id)

  def contact(_session, _target_id), do: {:error, :unknown_regional_body}

  def interrupt(session), do: LivingGameSession.interrupt_physical_action(session)
  def status(session), do: LivingGameSession.physical_action_status(session)
end
