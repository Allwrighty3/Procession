defmodule Procession.Simulation.RelationshipTopicPolicy do
  @moduledoc """
  Derives topic policy metadata from relationship metadata.

  This module does not apply internal field changes. It only converts
  relationship-shaped data into topic policy data that TopicPolicy can consume.
  """

  @default_sensitive_policy %{
    track?: true,
    sensitivity: :relationship_sensitive,
    base_salience: :high,
    first_boundary: :high,
    repeated_boundary: :very_high,
    trust_delta_on_press: -1
  }

  def from_relationships(entity_id, relationships)
      when is_binary(entity_id) and is_list(relationships) do
    relationships
    |> Enum.filter(&relationship_for_entity?(&1, entity_id))
    |> Enum.reduce(%{}, fn relationship, policies ->
      case policy_for_relationship(relationship) do
        {:ok, topic_key, policy} ->
          Map.put(policies, topic_key, policy)

        :ignore ->
          policies
      end
    end)
  end

  def from_relationships(_entity_id, _relationships), do: %{}

  defp relationship_for_entity?(relationship, entity_id) when is_map(relationship) do
    Map.get(relationship, :source_id) == entity_id or
      Map.get(relationship, :entity_id) == entity_id or
      Map.get(relationship, :from_id) == entity_id
  end

  defp relationship_for_entity?(_relationship, _entity_id), do: false

  defp policy_for_relationship(relationship) do
    topic_key = topic_key_for(relationship)

    if is_atom(topic_key) and not is_nil(topic_key) do
      {:ok, topic_key, relationship_policy(relationship)}
    else
      :ignore
    end
  end

  defp topic_key_for(relationship) do
    Map.get(relationship, :target_topic_key) ||
      topic_key_from_target_id(Map.get(relationship, :target_id)) ||
      topic_key_from_target_id(Map.get(relationship, :to_id))
  end

  defp topic_key_from_target_id("npc_" <> topic), do: String.to_atom(topic)
  defp topic_key_from_target_id(_target_id), do: nil

  defp relationship_policy(relationship) do
    @default_sensitive_policy
    |> Map.merge(optional_policy_values(relationship))
  end

  defp optional_policy_values(relationship) do
    [
      sensitivity: Map.get(relationship, :sensitivity),
      base_salience: Map.get(relationship, :base_salience),
      first_boundary: Map.get(relationship, :first_boundary) || Map.get(relationship, :disclosure_boundary),
      repeated_boundary: Map.get(relationship, :repeated_boundary),
      trust_delta_on_press: Map.get(relationship, :trust_delta_on_press)
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
