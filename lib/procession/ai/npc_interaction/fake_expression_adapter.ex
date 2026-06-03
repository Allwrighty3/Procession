defmodule Procession.AI.NPCInteraction.FakeExpressionAdapter do
  @moduledoc """
  Deterministic fake NPC expression adapter for tests and demos.

  This adapter returns a configured response when `:response` is provided,
  otherwise it returns a safe generic fallback-like response.
  """

  @behaviour Procession.AI.NPCInteraction.ExpressionAdapter

  @impl true
  def generate(_prompt, opts) do
    {:ok, Keyword.get(opts, :response, "I don't know enough to say that differently.")}
  end
end
