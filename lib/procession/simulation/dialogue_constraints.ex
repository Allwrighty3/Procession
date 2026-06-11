defmodule Procession.Simulation.DialogueConstraints do
  @moduledoc """
  Converts an internal field snapshot into structured dialogue constraints.

  This module does not generate dialogue. It does not call an LLM.
  It only translates internal field state into constraints that a later
  dialogue layer can use.
  """

  @default_constraints %{
    intent: :normal_response,
    disclosure_level: :normal,
    tone: [:neutral],
    allowed_facts: [],
    forbidden_topics: [],
    field_pressure: :none
  }

  def from_field_snapshot(%{topic_salience: topic_salience} = snapshot)
      when is_map(topic_salience) do
    mira_salience = Map.get(topic_salience, :mira)
    pressure_count = get_in(snapshot, [:topic_pressure_counts, :mira]) || 0

    cond do
      mira_salience == :high and pressure_count >= 2 ->
        repeated_mira_constraints(snapshot)

      mira_salience == :high ->
        high_mira_constraints(snapshot)

      true ->
        @default_constraints
    end
  end

  def from_field_snapshot(_snapshot), do: @default_constraints

  defp high_mira_constraints(_snapshot) do
    %{
      @default_constraints
      | intent: :guarded_deflection,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [:narrow_public_identity, :narrow_relationship_denial],
        forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
        field_pressure: :sensitive_topic
    }
  end

  defp repeated_mira_constraints(_snapshot) do
    %{
      @default_constraints
      | intent: :firm_deflection,
        disclosure_level: :none,
        tone: [:guarded, :firm],
        allowed_facts: [:narrow_relationship_denial],
        forbidden_topics: [
          :mira_location,
          :mira_private_history,
          :mira_hidden_relationship,
          :mira_current_activity
        ],
        field_pressure: :repeated_sensitive_topic
    }
  end
end
