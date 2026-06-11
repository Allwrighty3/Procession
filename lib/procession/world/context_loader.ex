defmodule Procession.World.ContextLoader do
  @moduledoc """
  Loads scoped world context for live simulation decisions.

  This module is a boundary between inert world storage and live simulation.
  It does not start processes, mutate internal fields, or apply behavior.
  """

  @behaviour Procession.World.PolicyContext

  alias Procession.Simulation.RelationshipTopicPolicy
  alias Procession.World.SQLiteStore

  def policy_context(conn, world_id, scope_id, entity_id) do
    relationships =
      SQLiteStore.relationships_for(
        conn,
        world_id,
        scope_id,
        entity_id
      )

    relationship_topic_policies =
      RelationshipTopicPolicy.from_relationships(
        entity_id,
        relationships
      )

    stored_topic_policies =
      SQLiteStore.topic_policies_for(
        conn,
        world_id,
        scope_id,
        entity_id
      )

    [
      relationships: relationships,
      topic_policies: merge_topic_policies(relationship_topic_policies, stored_topic_policies)
    ]
  end

  defp merge_topic_policies(relationship_topic_policies, stored_topic_policies) do
    Map.merge(relationship_topic_policies, stored_topic_policies, fn _topic_key, relationship_policy, stored_policy ->
      Map.merge(relationship_policy, stored_policy)
    end)
  end
end
