defmodule Procession.AI.FakeAdapter do
  @moduledoc """
  Deterministic AI adapter for tests and early development.

  This lets Phase 3 code be tested without requiring Ollama to be installed,
  running, or loaded with a model.
  """

  @behaviour Procession.AI

  @impl true
  @impl true
  def generate(prompt, opts) when is_binary(prompt) do
    constraints = Keyword.get(opts, :dialogue_constraints, %{})
    presentation = Keyword.get(opts, :presentation, %{})
    message_intent = Map.get(presentation, :message_intent, :general)

    cond do
      prompt =~ "- Name: Tobin" and
          constraints[:intent] == :firm_deflection and
          message_intent == :ask_location ->
        {:ok, "That's not something I share with strangers."}

      prompt =~ "- Name: Tobin" and
          constraints[:intent] == :firm_deflection ->
        {:ok, "I've answered enough about Mira."}

      prompt =~ "- Name: Tobin" and
          constraints[:intent] == :guarded_deflection and
          message_intent == :ask_public_identity ->
        {:ok, "A merchant. Why are you asking?"}

      prompt =~ "- Name: Tobin" and
          constraints[:intent] == :guarded_deflection and
          message_intent == :ask_relationship_denial ->
        {:ok, "No. Why are you asking?"}

      prompt =~ "- Name: Tobin" and constraints[:intent] == :guarded_deflection ->
        {:ok, "Why are you asking about Mira?"}

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
