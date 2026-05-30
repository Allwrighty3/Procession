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
end
