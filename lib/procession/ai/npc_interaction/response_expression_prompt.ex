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
  def render(intent, fallback_response) do
    render(intent, fallback_response, [])
  end

  @doc """
  Renders an expression prompt from a validated response intent, deterministic
  fallback, and optional expression context.

  Supported options:

  - `:voice_profile` - map describing speaker tone/style.
  - `:relationship_stance` - map describing the speaker's subjective stance
    toward another entity.
  - `:emotional_state` - map describing the speaker's current mood,
    intensity, restraint, stress, or emotional pressure.
  - `:delivery_style` - map or string describing the response shape,
    such as terse, warm, sharp, controlled, rambling, or eager.
  - `:conversational_move` - map or string describing what the line
    should do in conversation, such as answer only, ask a follow-up,
    challenge a premise, warn, redirect, or refuse.
  - `:recent_memory` - map describing validated recent memory influence,
    relevance, stance effect, and reference policy.
  """
  @spec render(map(), String.t(), keyword()) :: render_result()
  def render(intent, fallback_response, opts)
      when is_map(intent) and is_binary(fallback_response) and is_list(opts) do
    with {:ok, validated_intent} <- ResponseIntentValidator.validate(intent) do
      {:ok, do_render(validated_intent, fallback_response, opts)}
    end
  end

  def render(_intent, _fallback_response, _opts) do
    {:error, :invalid_expression_prompt_input}
  end

  defp do_render(intent, fallback_response, opts) do
    """
    ### Task
    Rewrite the fallback NPC line so it sounds more natural, conversational, and in-character.

    ### Hard Rules
    - Return only the final NPC line.
    - Do not use JSON.
    - Do not explain your reasoning.
    - Do not add objective world facts.
    - You may add subjective tone, attitude, opinion, and phrasing when supported by the expression context.
    - You do not need to mention every known fact.
    - You may ask a natural follow-up question if the conversational move supports it.
    - Short answers are valid when the delivery style calls for them.
    - Do not explain every grounded fact unless the character would naturally say it.
    - Do not change speaker identity.
    - Do not change entity roles, locations, relationships, or current activity.
    - Do not mention forbidden inventions as true.
    - If the fallback expresses uncertainty, preserve that uncertainty.
    - Recent memory may influence tone, warmth, suspicion, patience, cooperation, or detail.
    - Do not mention recent memory directly unless the memory reference policy allows it.
    - If recent memory is irrelevant or marked do_not_reference, let it affect tone only or ignore it.
    - Do not invent events, history, promises, favors, threats, or relationships from memory context.

    ### Response Intent
    #{Jason.encode!(intent, pretty: true)}

    ### Expression Context
    #{Jason.encode!(expression_context(opts), pretty: true)}

    ### Deterministic Fallback
    #{fallback_response}

    ### Final NPC Line
    """
    |> String.trim_trailing()
  end

  defp expression_context(opts) do
    %{
      "voice_profile" => Keyword.get(opts, :voice_profile, %{}),
      "relationship_stance" => Keyword.get(opts, :relationship_stance, %{}),
      "emotional_state" => Keyword.get(opts, :emotional_state, %{}),
      "delivery_style" => Keyword.get(opts, :delivery_style, "plain"),
      "conversational_move" => Keyword.get(opts, :conversational_move, "answer_only"),
      "recent_memory" => Keyword.get(opts, :recent_memory, %{}),
      "style_permissions" => %{
        "may_use_subjective_opinion" => true,
        "may_omit_nonessential_known_facts" => true,
        "may_use_follow_up_questions" => true,
        "may_use_short_answers" => true,
        "must_not_add_objective_world_facts" => true
      }
    }
  end
end
