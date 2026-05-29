defmodule Procession.Game do
  @moduledoc """
  Public gameplay boundary for player-facing inspection and actions.

  This module should orchestrate existing systems without owning long-lived state.
  Start with plain function calls before adding command parsing, LiveView, or
  stateful gameplay processes.
  """

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Generator

  @doc """
  Inspects a live entity and returns a player-facing summary as plain data.

  Returns `{:ok, summary}` for existing entities and
  `{:error, :entity_not_found}` for missing entities.
  """
  def look(entity_id) do
    if EntitySupervisor.exists?(entity_id) do
      state = Entity.get_state(entity_id)

      {:ok,
       %{
         id: state.id,
         name: state.name,
         type: state.type,
         location: state.location,
         status: state.status,
         traits: state.traits,
         relationships: Map.get(state.metadata, :relationships, []),
         description: Map.get(state.metadata, :description),
         memory_summary: Entity.memory_summary(entity_id)
       }}
    else
      {:error, :entity_not_found}
    end
  end

  @doc """
  Returns matching memories for an entity and topic.

  This is deterministic and returns memory entries as data. It does not summarize,
  call AI, or mutate entity state.
  """

  def ask_about(entity_id, topic) when is_binary(topic) do
    if EntitySupervisor.exists?(entity_id) do
      {:ok, Entity.recall(entity_id, topic)}
    else
      {:error, :entity_not_found}
    end
  end

  def ask_about(_entity_id, _topic) do
    {:error, :invalid_topic}
  end

  @doc """
  Requests dialogue from an NPC.

  This delegates to the existing entity AI response boundary and returns generated
  dialogue as data. It does not mutate NPC state from the generated response.
  """
  def talk_to(npc_id, player_message, opts \\ []) when is_binary(player_message) do
    if EntitySupervisor.exists?(npc_id) do
      Entity.generate_response(npc_id, player_message, opts)
    else
      {:error, :entity_not_found}
    end
  end

  def talk_to(_npc_id, _player_message, _opts) do
    {:error, :invalid_message}
  end

  @doc """
  Creates a deterministic playable world from a prompt.

  This uses the deterministic generator path, validates the generated blueprint,
  spawns live entity processes and returns a player-facing setup summary.
  """

  def new_game(prompt) do
    with {:ok, blueprint} <- Generator.generate_world(prompt),
         :ok <- Generator.validate_blueprint(blueprint),
         {:ok, spawn_summary} <- Generator.spawn_world(blueprint) do
      {:ok,
       %{
         name: blueprint.name,
         description: blueprint.description,
         prompt: blueprint.prompt,
         locations: spawn_summary.locations,
         npcs: spawn_summary.npcs,
         factions: spawn_summary.factions,
         relationships: spawn_summary.relationships,
         starter_memories: spawn_summary.starter_memories
       }}
    end
  end

  @doc """
  Performs a tiny deterministic player action.

  The first supported action is `:look`, which delegates to `look/1`.
  """
  def perform(:look, opts) when is_list(opts) do
    with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target) do
      look(entity_id)
    end
  end

  def perform(:ask_about, opts) when is_list(opts) do
    with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target),
         {:ok, topic} <- fetch_required_opt(opts, :topic, :missing_topic) do
      ask_about(entity_id, topic)
    end
  end

  def perform(_action, _opts) do
    {:error, :invalid_action}
  end

  defp fetch_required_opt(opts, key, error_reason) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, error_reason}
    end
  end
end
