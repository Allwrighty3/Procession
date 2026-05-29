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
end
