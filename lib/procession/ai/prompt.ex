defmodule Procession.AI.Prompt do
  @moduledoc """
  Small prompt-building helpers for request-based local AI calls.

  These helpers turn structured game state into plain prompt strings.
  They do not call an AI model and do not mutate entity state.
  """

  def npc_response(attrs) when is_map(attrs) do
    name = Map.get(attrs, :name, "Unknown NPC")
    status = Map.get(attrs, :status, :idle)
    location = Map.get(attrs, :location, "unknown location")
    location_context = Map.get(attrs, :location_context)
    traits = Map.get(attrs, :traits, %{})
    memories = Map.get(attrs, :memories, [])
    speaker = Map.get(attrs, :speaker, %{id: "player", type: :player, name: "Player"})
    message = Map.get(attrs, :message, Map.get(attrs, :player_message, ""))

    """
    You are generating dialogue for a single-player RPG simulation.

    Entity:
    - Name: #{name}
    - Status: #{status}
    - Location: #{location}

    Traits:
    #{format_traits(traits)}

    Relevant memories:
    #{format_memories(memories)}

    Current location context:
    #{format_location_context(location_context)}

    Speaker:
    - Name: #{Map.get(speaker, :name, "Unknown speaker")}
    - Type: #{Map.get(speaker, :type, :unknown)}
    - ID: #{Map.get(speaker, :id, "unknown")}

    Message:
    #{message}

    Respond as the NPC in 1-3 sentences.
    """
    |> String.trim()
  end

  def grounded_npc_response(context) when is_map(context) do
    target = Map.get(context, :target, %{})
    speaker = Map.get(context, :speaker, %{id: "player", type: :player, name: "Player"})
    location = Map.get(context, :location)
    active_entities = Map.get(context, :active_entities, [])
    memories = Map.get(context, :target_memories, [])
    message = Map.get(context, :message, "")

    """
    You are generating dialogue for a single-player RPG simulation.

    Identity rule:
    You are #{Map.get(target, :name, "Unknown NPC")} and only #{Map.get(target, :name, "Unknown NPC")}.
    Your entity ID is #{Map.get(target, :id, "unknown")}.
    Do not claim to be any other entity listed in the context.
    Listed entities are world facts, not your identity.
    If the player asks about another entity, describe that entity from the grounded context while continuing to speak as #{Map.get(target, :name, "Unknown NPC")}.

    Grounding rule:
    Use only the grounded context below.
    Do not invent names, relationships, locations, occupations, memories, or events that are not present in the context.
    If the answer is not known from the context, respond with uncertainty in #{Map.get(target, :name, "Unknown NPC")}'s voice.

    Target NPC:
    - ID: #{Map.get(target, :id, "unknown")}
    - Name: #{Map.get(target, :name, "Unknown NPC")}
    - Type: #{Map.get(target, :type, :unknown)}
    - Status: #{Map.get(target, :status, :idle)}
    - Location: #{Map.get(target, :location, "unknown location")}

    Target traits:
    #{format_traits(Map.get(target, :traits, %{}))}

    Speaker:
    - ID: #{Map.get(speaker, :id, "unknown")}
    - Name: #{Map.get(speaker, :name, "Unknown speaker")}
    - Type: #{Map.get(speaker, :type, :unknown)}

    Current location:
    #{format_grounded_location(location)}

    Scene entities:
    #{format_scene_entities(active_entities, Map.get(target, :location))}

    Other known NPCs:
    #{format_other_npcs(active_entities, Map.get(target, :location))}

    Known locations:
    #{format_known_locations(active_entities)}

    Known factions:
    #{format_known_factions(active_entities)}

    Relevant target memories:
    #{format_memories(memories)}

    Player message:
    #{message}

    Respond as #{Map.get(target, :name, "Unknown NPC")} in 1-3 sentences.
    Only scene entities are physically present with Tobin.
    Other known NPCs are not at Tobin's location unless their location exactly matches Tobin's location.
    Do not infer plans, services, relationships, reputation, or current activity unless explicitly listed.
    Do not start by saying you are another entity.
    """
    |> String.trim()
  end

  defp format_traits(traits) when map_size(traits) == 0 do
    "- none"
  end

  defp format_traits(traits) do
    traits
    |> Enum.map(fn {key, value} -> "- #{key}: #{value}" end)
    |> Enum.join("\n")
  end

  defp format_memories([]), do: "- none"

  defp format_memories(memories) do
    memories
    |> Enum.map(fn memory ->
      content = Map.get(memory, :content, "")
      type = Map.get(memory, :type, :memory)
      importance = Map.get(memory, :importance, 1)

      "- [#{type}, importance #{importance}] #{content}"
    end)
    |> Enum.join("\n")
  end

  defp format_location_context(nil), do: "- none"

  defp format_location_context(location) do
    name = Map.get(location, :name, "Unknown location")
    description = Map.get(location, :description, "No description available.")

    "- Name: #{name}\n- Description: #{description}"
  end

  defp format_grounded_location(nil), do: "- none"

  defp format_grounded_location(location) do
    exits = Map.get(location, :exits, [])

    """
    - ID: #{Map.get(location, :id, "unknown")}
    - Name: #{Map.get(location, :name, "Unknown location")}
    - Type: #{Map.get(location, :type, :unknown)}
    - Description: #{Map.get(location, :description, "No description available.")}
    - Exits:
    #{format_exits(exits)}
    """
    |> String.trim()
  end

  defp format_exits([]), do: "  - none"

  defp format_exits(exits) do
    exits
    |> Enum.map(fn exit ->
      to = Map.get(exit, :to, "unknown")
      label = Map.get(exit, :label, "unknown path")

      "  - #{label} -> #{to}"
    end)
    |> Enum.join("\n")
  end

  defp format_scene_entities(entities, target_location) do
    entities
    |> Enum.filter(fn entity ->
      Map.get(entity, :location) == target_location and
        Map.get(entity, :type) in [:npc, :player]
    end)
    |> case do
      [] ->
        "- none"

      scene_entities ->
        scene_entities
        |> Enum.map(fn entity ->
          "- #{Map.get(entity, :name, "Unknown")} (#{Map.get(entity, :id, "unknown")}, #{Map.get(entity, :type, :unknown)}) at #{Map.get(entity, :location, "unknown location")} status=#{Map.get(entity, :status, :idle)} traits=#{format_traits_inline(Map.get(entity, :traits, %{}))}"
        end)
        |> Enum.join("\n")
    end
  end

  defp format_other_npcs(entities, target_location) do
    entities
    |> Enum.filter(fn entity ->
      Map.get(entity, :type) == :npc and
        Map.get(entity, :location) != target_location
    end)
    |> case do
      [] ->
        "- none"

      npcs ->
        npcs
        |> Enum.map(fn entity ->
          "- #{Map.get(entity, :name, "Unknown")} (#{Map.get(entity, :id, "unknown")}) is at #{Map.get(entity, :location, "unknown location")} with traits=#{format_traits_inline(Map.get(entity, :traits, %{}))}"
        end)
        |> Enum.join("\n")
    end
  end

  defp format_known_locations(entities) do
    entities
    |> Enum.filter(fn entity -> Map.get(entity, :type) == :location end)
    |> case do
      [] ->
        "- none"

      locations ->
        locations
        |> Enum.map(fn entity ->
          "- #{Map.get(entity, :name, "Unknown location")} (#{Map.get(entity, :id, "unknown")})"
        end)
        |> Enum.join("\n")
    end
  end

  defp format_known_factions(entities) do
    entities
    |> Enum.filter(fn entity -> Map.get(entity, :type) == :faction end)
    |> case do
      [] ->
        "- none"

      factions ->
        factions
        |> Enum.map(fn entity ->
          "- #{Map.get(entity, :name, "Unknown faction")} (#{Map.get(entity, :id, "unknown")})"
        end)
        |> Enum.join("\n")
    end
  end

  defp format_traits_inline(traits) when traits == %{}, do: "none"

  defp format_traits_inline(traits) do
    traits
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.join(", ")
  end
end
