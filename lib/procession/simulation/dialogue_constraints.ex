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
    field_pressure: :none
  }

  def from_field_snapshot(snapshot, presentation \\ %{})

  def from_field_snapshot(%{topic_salience: topic_salience} = snapshot, presentation)
      when is_map(topic_salience) and is_map(presentation) do
    mira_salience = Map.get(topic_salience, :mira)
    pressure_count = get_in(snapshot, [:topic_pressure_counts, :mira]) || 0
    message_intent = Map.get(presentation, :message_intent, :general)

    cond do
      mira_salience == :high and message_intent == :ask_location ->
        mira_location_refusal_constraints(snapshot)

      mira_salience == :high and pressure_count >= 2 ->
        repeated_mira_constraints(snapshot)

      mira_salience == :high and message_intent == :ask_public_identity ->
        mira_public_identity_constraints(snapshot)

      mira_salience == :high and message_intent == :ask_relationship_denial ->
        mira_relationship_denial_constraints(snapshot)

      mira_salience == :high ->
        high_mira_constraints(snapshot)

      true ->
        @default_constraints
    end
  end

  def from_field_snapshot(_snapshot, _presentation), do: @default_constraints

  defp mira_public_identity_constraints(_snapshot) do
    %{
      @default_constraints
      | intent: :guarded_deflection,
        response_shape: :public_identity_then_question,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [:narrow_public_identity],
        forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
        field_pressure: :sensitive_topic
    }
  end

  defp mira_relationship_denial_constraints(_snapshot) do
    %{
      @default_constraints
      | intent: :guarded_deflection,
        response_shape: :relationship_denial_then_question,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [:narrow_relationship_denial],
        forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
        field_pressure: :sensitive_topic
    }
  end

  defp high_mira_constraints(_snapshot) do
    %{
      @default_constraints
      | intent: :guarded_deflection,
        response_shape: :ask_why,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [],
        forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
        field_pressure: :sensitive_topic
    }
  end

  defp repeated_mira_constraints(_snapshot) do
    %{
      @default_constraints
      | intent: :firm_deflection,
        response_shape: :repeated_topic_boundary,
        disclosure_level: :none,
        tone: [:guarded, :firm],
        allowed_facts: [],
        forbidden_topics: [
          :mira_location,
          :mira_private_history,
          :mira_hidden_relationship,
          :mira_current_activity
        ],
        field_pressure: :repeated_sensitive_topic
    }
  end

  defp mira_location_refusal_constraints(_snapshot) do
    %{
      @default_constraints
      | intent: :firm_deflection,
        response_shape: :location_refusal,
        disclosure_level: :none,
        tone: [:guarded, :firm],
        allowed_facts: [],
        forbidden_topics: [
          :mira_location,
          :mira_private_history,
          :mira_hidden_relationship,
          :mira_current_activity
        ],
        field_pressure: :sensitive_location_request
    }
  end
end
