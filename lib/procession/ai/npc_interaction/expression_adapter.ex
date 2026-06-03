defmodule Procession.AI.NPCInteraction.ExpressionAdapter do
  @moduledoc """
  Adapter contract for NPC response expression models.

  Expression adapters receive a rendered expression prompt and return candidate
  NPC dialogue text. They do not decide truth, entity identity, relationships,
  roles, locations, or gameplay state.

  The returned candidate must still pass response text validation before it can
  be shown to the player.
  """

  @type generate_result :: {:ok, String.t()} | {:error, term()}

  @callback generate(String.t(), keyword()) :: generate_result()
end
