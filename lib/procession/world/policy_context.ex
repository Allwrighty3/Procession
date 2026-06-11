defmodule Procession.World.PolicyContext do
  @moduledoc """
  Builds TopicPolicy-ready context for a specific live simulation entity.

  This module is intentionally small. It gives higher-level systems one stable
  place to ask for scoped policy context without depending directly on SQLite,
  schema details, or relationship query mechanics.
  """

  @type context :: keyword()
  @type loader :: module()
  @type connection :: term()
  @type world_id :: binary()
  @type scope_id :: binary()
  @type entity_id :: binary()

  @callback policy_context(connection(), world_id(), scope_id(), entity_id()) :: context()

  def for_entity(loader, conn, world_id, scope_id, entity_id)
      when is_atom(loader) and is_binary(world_id) and is_binary(scope_id) and is_binary(entity_id) do
    loader.policy_context(conn, world_id, scope_id, entity_id)
    |> normalize_context()
  end

  def for_entity(_loader, _conn, _world_id, _scope_id, _entity_id) do
    empty_context()
  end

  def empty_context do
    [
      relationships: [],
      topic_policies: %{}
    ]
  end

  defp normalize_context(context) when is_list(context) do
    relationships =
      context
      |> Keyword.get(:relationships, [])
      |> normalize_relationships()

    topic_policies =
      context
      |> Keyword.get(:topic_policies, %{})
      |> normalize_topic_policies()

    [
      relationships: relationships,
      topic_policies: topic_policies
    ]
  end

  defp normalize_context(_context), do: empty_context()

  defp normalize_relationships(relationships) when is_list(relationships), do: relationships
  defp normalize_relationships(_relationships), do: []

  defp normalize_topic_policies(topic_policies) when is_map(topic_policies), do: topic_policies
  defp normalize_topic_policies(_topic_policies), do: %{}
end
