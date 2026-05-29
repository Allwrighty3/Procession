defmodule Procession.Generator.Prompt do
  @moduledoc """
  Prompt-building helpers for procedural world generation.

  These helpers only build plain strings. They do not call AI, parse AI output,
  spawn entities, or mutate game state.
  """

  @doc """
  Builds a prompt asking for a small world blueprint.

  This is preparation for future AI-assisted generation. The deterministic
  generator remains the source of truth for tests and gameplay until AI output
  parsing is added later.
  """
  def world_blueprint(prompt) when is_binary(prompt) do
    """
    You are helping generate a small world blueprint for a single-player RPG simulation.

    Player prompt:
    #{prompt}

    Return one small structured world blueprint.

    Requirements:
    - Include exactly 3 locations.
    - Include exactly 3 NPCs.
    - Include exactly 1 faction.
    - Include 1-3 relationships between generated entities.
    - Include 1-3 starter memories or rumors for NPCs.
    - Use string IDs.
    - Location IDs must start with "loc_".
    - NPC IDs must start with "npc_".
    - Faction IDs must start with "faction_".
    - NPC locations must refer to generated location IDs.
    - Relationships must refer to generated entity IDs.
    - Starter memories must refer to generated NPC IDs.
    - Keep descriptions short.
    - Do not create a large world.

    Expected top-level fields:
    - name
    - description
    - locations
    - npcs
    - factions
    - relationships
    - starter_memories

    Return only the blueprint content. Do not include explanations.
    """
    |> String.trim()
  end

  def world_blueprint(_prompt) do
    {:error, :invalid_prompt}
  end
end
