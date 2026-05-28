defmodule Procession.AI.FakeAdapter do
  @moduledoc """
  Deterministic AI adapter for tests and early development.

  This lets Phase 3 code be tested without requiring Ollama to be installed,
  running, or loaded with a model.
  """

  @behaviour Procession.AI

  @impl true
  def generate(prompt, _opts) when is_binary(prompt) do
    {:ok, "AI response to: #{prompt}"}
  end

  def generate(_prompt, _opts) do
    {:error, :invalid_prompt}
  end
end
