defmodule Procession.Simulation.DialogueConstraints do
  @moduledoc """
  Converts an internal field snapshot and current presentation into structured
  dialogue constraints.

  This module does not generate dialogue. It does not call an LLM.
  It translates simulation-owned internal field state into response policy.
  """

  @default_constraints %{
    intent: :normal_response,
    response_shape: :open_response,
    disclosure_level: :normal,
    tone: [:neutral],
    allowed_facts: [],
    forbidden_topics: [],
    field_pressure: :none,
    topic_key: :general,
    target_name: nil,
    target_public_facts: %{}
  }

  def from_field_snapshot(snapshot, presentation \\ %{})

  def from_field_snapshot(%{topic_salience: topic_salience} = snapshot, presentation)
      when is_map(topic_salience) and is_map(presentation) do
    topic_key = Map.get(presentation, :topic_key, :general)
    target_name = Map.get(presentation, :target_name)
    target_public_facts = Map.get(presentation, :target_public_facts, %{})
    topic_salience_level = Map.get(topic_salience, topic_key)
    pressure_count = get_in(snapshot, [:topic_pressure_counts, topic_key]) || 0
    message_intent = Map.get(presentation, :message_intent, :general)

    cond do
      topic_key == :general ->
        @default_constraints

      topic_salience_level == :high and message_intent == :ask_location ->
        location_refusal_constraints(topic_key, target_name, target_public_facts)

      topic_salience_level == :high and pressure_count >= 2 ->
        repeated_topic_constraints(topic_key, target_name, target_public_facts)

      topic_salience_level == :high and message_intent == :ask_public_identity ->
        public_identity_constraints(topic_key, target_name, target_public_facts)

      topic_salience_level == :high and message_intent == :ask_relationship_denial ->
        relationship_denial_constraints(topic_key, target_name, target_public_facts)

      topic_salience_level == :high ->
        sensitive_topic_constraints(topic_key, target_name, target_public_facts)

      true ->
        @default_constraints
    end
  end

  def from_field_snapshot(_snapshot, _presentation), do: @default_constraints

  defp public_identity_constraints(topic_key, target_name, target_public_facts) do
    %{
      @default_constraints
      | intent: :guarded_deflection,
        response_shape: :public_identity_then_question,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [:narrow_public_identity],
        forbidden_topics: forbidden_private_topics(topic_key),
        field_pressure: :sensitive_topic,
        topic_key: topic_key,
        target_name: target_name,
        target_public_facts: target_public_facts
    }
  end

  defp relationship_denial_constraints(topic_key, target_name, target_public_facts) do
    %{
      @default_constraints
      | intent: :guarded_deflection,
        response_shape: :relationship_denial_then_question,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [:narrow_relationship_denial],
        forbidden_topics: forbidden_private_topics(topic_key),
        field_pressure: :sensitive_topic,
        topic_key: topic_key,
        target_name: target_name,
        target_public_facts: target_public_facts
    }
  end

  defp sensitive_topic_constraints(topic_key, target_name, target_public_facts) do
    %{
      @default_constraints
      | intent: :guarded_deflection,
        response_shape: :ask_why,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [],
        forbidden_topics: forbidden_private_topics(topic_key),
        field_pressure: :sensitive_topic,
        topic_key: topic_key,
        target_name: target_name,
        target_public_facts: target_public_facts
    }
  end

  defp repeated_topic_constraints(topic_key, target_name, target_public_facts) do
    %{
      @default_constraints
      | intent: :firm_deflection,
        response_shape: :repeated_topic_boundary,
        disclosure_level: :none,
        tone: [:guarded, :firm],
        allowed_facts: [],
        forbidden_topics:
          forbidden_private_topics(topic_key) ++ [:"#{topic_key}_current_activity"],
        field_pressure: :repeated_sensitive_topic,
        topic_key: topic_key,
        target_name: target_name,
        target_public_facts: target_public_facts
    }
  end

  defp location_refusal_constraints(topic_key, target_name, target_public_facts) do
    %{
      @default_constraints
      | intent: :firm_deflection,
        response_shape: :location_refusal,
        disclosure_level: :none,
        tone: [:guarded, :firm],
        allowed_facts: [],
        forbidden_topics:
          forbidden_private_topics(topic_key) ++ [:"#{topic_key}_current_activity"],
        field_pressure: :sensitive_location_request,
        topic_key: topic_key,
        target_name: target_name,
        target_public_facts: target_public_facts
    }
  end

  defp forbidden_private_topics(topic_key) when is_atom(topic_key) do
    [
      :"#{topic_key}_location",
      :"#{topic_key}_private_history",
      :"#{topic_key}_hidden_relationship"
    ]
  end
end
