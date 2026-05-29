defmodule Procession.Generator do
  @moduledoc """
  Public boundary for procedural world generation.

  The generator returns world blueprints as plain maps. It does not start entity
  processes or mutate game state.
  """

  @doc """
  Generates a small deterministic world blueprint from a prompt.

  This first version is intentionally deterministic and does not call AI.
  """
  def generate_world(prompt, _opts \\ []) when is_binary(prompt) do
    {:ok,
     %{
       name: "Echoes of the Old Road",
       description:
         "A small frontier region shaped by old rumors, wary travelers, and a forgotten mine.",
       prompt: prompt,
       locations: [
         %{
           id: "loc_crossroads",
           name: "Old Road Crossroads",
           type: :location,
           description:
             "A muddy crossroads where merchants, pilgrims, and trouble all seem to pass through."
         },
         %{
           id: "loc_briar_village",
           name: "Briar Village",
           type: :location,
           description:
             "A tired village of timber homes, suspicious windows, and stubborn survivors."
         },
         %{
           id: "loc_silent_mine",
           name: "Silent Mine",
           type: :location,
           description: "An abandoned mine where the locals insist the echoes answer back."
         }
       ],
       npcs: [
         %{
           id: "npc_mira",
           name: "Mira",
           type: :npc,
           location: "loc_briar_village",
           traits: %{role: "innkeeper", temperament: "watchful"}
         },
         %{
           id: "npc_tobin",
           name: "Tobin",
           type: :npc,
           location: "loc_crossroads",
           traits: %{role: "merchant", temperament: "nervous"}
         },
         %{
           id: "npc_elin",
           name: "Elin",
           type: :npc,
           location: "loc_silent_mine",
           traits: %{role: "scout", temperament: "reckless"}
         }
       ],
       factions: [
         %{
           id: "faction_roadwardens",
           name: "Roadwardens",
           type: :faction,
           description:
             "A loose band of locals who keep the roads safe when they can and profitable when they cannot."
         }
       ],
       relationships: [
         %{
           from: "npc_mira",
           to: "npc_tobin",
           type: :distrusts,
           description: "Mira thinks Tobin knows more about the mine than he admits."
         },
         %{
           from: "npc_elin",
           to: "faction_roadwardens",
           type: :member_of,
           description: "Elin scouts dangerous roads for the Roadwardens."
         }
       ],
       starter_memories: [
         %{
           entity_id: "npc_mira",
           type: :rumor,
           content: "Tobin was seen near the Silent Mine after sundown.",
           importance: 3,
           tags: [:mine, :tobin, :rumor]
         },
         %{
           entity_id: "npc_tobin",
           type: :observation,
           content: "The old road has been quieter since the mine started echoing again.",
           importance: 2,
           tags: [:road, :mine]
         }
       ]
     }}
  end

  def generate_world(_prompt, _opts) do
    {:error, :invalid_prompt}
  end

  @doc """
  Validates a generated world blueprint.

  This is intentionally small and map-based for now. It checks only the minimum
  shape needed before generated worlds can eventually be spawned into live entity
  processes.
  """
  def validate_blueprint(blueprint) when is_map(blueprint) do
    with :ok <- require_top_level_fields(blueprint),
         :ok <- require_unique_entity_ids(blueprint),
         :ok <- require_known_npc_locations(blueprint),
         :ok <- require_known_relationship_entities(blueprint),
         :ok <- require_valid_starter_memories(blueprint) do
      :ok
    end
  end

  def validate_blueprint(_blueprint) do
    {:error, :invalid_blueprint}
  end

  defp require_top_level_fields(blueprint) do
    required_fields = [
      :name,
      :description,
      :prompt,
      :locations,
      :npcs,
      :factions,
      :relationships,
      :starter_memories
    ]

    case Enum.find(required_fields, fn field -> not Map.has_key?(blueprint, field) end) do
      nil -> :ok
      field -> {:error, {:missing_field, field}}
    end
  end

  defp require_unique_entity_ids(blueprint) do
    ids = entity_ids(blueprint)

    if length(ids) == length(Enum.uniq(ids)) do
      :ok
    else
      {:error, :duplicate_entity_ids}
    end
  end

  defp entity_ids(blueprint) do
    blueprint.locations
    |> Enum.concat(blueprint.npcs)
    |> Enum.concat(blueprint.factions)
    |> Enum.map(&Map.get(&1, :id))
  end

  defp require_known_npc_locations(blueprint) do
    location_ids = Enum.map(blueprint.locations, & &1.id)

    case Enum.find(blueprint.npcs, fn npc -> npc.location not in location_ids end) do
      nil -> :ok
      npc -> {:error, {:unknown_location, npc.id, npc.location}}
    end
  end

  defp require_known_relationship_entities(blueprint) do
    ids = entity_ids(blueprint)

    case Enum.find(blueprint.relationships, fn relationship ->
           relationship.from not in ids or relationship.to not in ids
         end) do
      nil ->
        :ok

      relationship ->
        {:error, {:unknown_relationship_entity, relationship}}
    end
  end

  defp require_valid_starter_memories(blueprint) do
    npc_ids = Enum.map(blueprint.npcs, & &1.id)

    case Enum.find(blueprint.starter_memories, fn memory ->
           invalid_starter_memory?(memory, npc_ids)
         end) do
      nil -> :ok
      memory -> {:error, {:invalid_starter_memory, memory}}
    end
  end

  defp invalid_starter_memory?(memory, npc_ids) do
    Map.get(memory, :entity_id) not in npc_ids or
      not Map.has_key?(memory, :type) or
      not Map.has_key?(memory, :content) or
      Map.get(memory, :content) in [nil, ""]
  end
end
