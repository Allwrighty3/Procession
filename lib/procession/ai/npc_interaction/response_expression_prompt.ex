defmodule Procession.AI.NPCInteraction.ResponseExpressionPrompt do
  @moduledoc """
  Renders prompts for NPC response expression.

  Expression prompts ask a model to restyle already-validated response intent
  into natural NPC dialogue. The model is not asked to decide truth, identity,
  or gameplay facts.

  This module does not call AI, mutate simulation state, or execute gameplay
  behavior.
  """

  alias Procession.AI.NPCInteraction.ResponseIntentValidator

  @type render_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Renders an expression prompt from a validated response intent and deterministic fallback.

  The prompt tells a model to produce only the final NPC line while preserving
  the already validated meaning.
  """
  @spec render(map(), String.t()) :: render_result()
  def render(intent, fallback_response) when is_map(intent) and is_binary(fallback_response) do
    with {:ok, validated_intent} <- ResponseIntentValidator.validate(intent) do
      {:ok, do_render(validated_intent, fallback_response)}
    end
  end

  def render(_intent, _fallback_response) do
    {:error, :invalid_expression_prompt_input}
  end

  defp do_render(intent, fallback_response) do
    """
    ### Task
    Rewrite the fallback NPC line so it sounds more natural, conversational, and in-character.

    ### Hard Rules
    - Return only the final NPC line.
    - Do not use JSON.
    - Do not explain your reasoning.
    - Do not add facts.
    - Do not change speaker identity.
    - Do not change entity roles, locations, relationships, or current activity.
    - Do not mention forbidden inventions.
    - If the fallback expresses uncertainty, preserve that uncertainty.

    ### Response Intent
    #{Jason.encode!(intent, pretty: true)}

    ### Deterministic Fallback
    #{fallback_response}

    ### Final NPC Line
    """
    |> String.trim_trailing()
  end
end
