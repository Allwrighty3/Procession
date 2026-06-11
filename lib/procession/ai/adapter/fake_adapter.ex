defmodule Procession.AI.FakeAdapter do
  @moduledoc """
  Deterministic AI adapter for tests and early development.

  This lets Procession exercise dialogue paths without requiring Ollama or a
  local model. It renders from structured dialogue constraints when present.
  """

  @behaviour Procession.AI

  @impl true
  def generate(prompt, opts) when is_binary(prompt) do
    constraints = Keyword.get(opts, :dialogue_constraints, %{})
    response_shape = Map.get(constraints, :response_shape)
    target_name = Map.get(constraints, :target_name) || "that"

    cond do
      prompt =~ "- Name: Tobin" and response_shape == :public_identity_then_question ->
        {:ok, "#{target_name} is a merchant. Why are you asking?"}

      prompt =~ "- Name: Tobin" and response_shape == :relationship_denial_then_question ->
        {:ok, "No. Why are you asking?"}

      prompt =~ "- Name: Tobin" and response_shape == :location_refusal ->
        {:ok, "That's not something I share with strangers."}

      prompt =~ "- Name: Tobin" and response_shape == :repeated_topic_boundary ->
        {:ok, "I've answered enough about #{target_name}."}

      prompt =~ "- Name: Tobin" and response_shape == :ask_why ->
        {:ok, "Why are you asking about #{target_name}?"}

      prompt =~ "- Name: Tobin" ->
        {:ok,
         "Keep your voice down. The road has been too quiet, and quiet roads usually mean someone is listening."}

      prompt =~ "- Name: Mira" ->
        {:ok, "If Tobin is finally admitting trouble, then the mine is worse than I thought."}

      true ->
        {:ok, "I have nothing new to say right now."}
    end
  end

  def generate(_prompt, _opts) do
    {:error, :invalid_prompt}
  end
end
