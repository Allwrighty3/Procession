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
  def generate_world(prompt, opts \\ [])

  def generate_world(prompt, _opts) when is_binary(prompt) do
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
             "A muddy crossroads where merchants, pilgrims, and trouble all seem to pass through.",
           exits: [
             %{to: "loc_briar_village", label: "village road"},
             %{to: "loc_silent_mine", label: "mine road"}
           ]
         },
         %{
           id: "loc_briar_village",
           name: "Briar Village",
           type: :location,
           description:
             "A tired village of timber homes, suspicious windows, and stubborn survivors.",
           exits: [
             %{to: "loc_crossroads", label: "old road"}
           ]
         },
         %{
           id: "loc_silent_mine",
           name: "Silent Mine",
           type: :location,
           description: "An abandoned mine where the locals insist the echoes answer back.",
           exits: [
             %{to: "loc_crossroads", label: "mine road"}
           ]
         }
       ],
       npcs: [
         %{
           id: "npc_mira",
           name: "Mira",
           type: :npc,
           location: "loc_briar_village",
           traits: %{role: "innkeeper", temperament: "watchful"},
           metadata: %{
             topic_policies: %{
               tobin: %{
                 track?: true,
                 sensitivity: :relationship_sensitive,
                 base_salience: :high,
                 first_boundary: :high,
                 repeated_boundary: :very_high,
                 trust_delta_on_press: -1
               },
               weather: %{
                 track?: false,
                 sensitivity: :neutral,
                 base_salience: :none,
                 first_boundary: :none,
                 repeated_boundary: :none,
                 trust_delta_on_press: 0
               }
             }
           }
         },
         %{
           id: "npc_tobin",
           name: "Tobin",
           type: :npc,
           location: "loc_crossroads",
           traits: %{role: "merchant", temperament: "nervous"},
           metadata: %{
             topic_policies: %{
               mira: %{
                 track?: true,
                 sensitivity: :relationship_sensitive,
                 base_salience: :high,
                 first_boundary: :high,
                 repeated_boundary: :very_high,
                 trust_delta_on_press: -1
               },
               weather: %{
                 track?: false,
                 sensitivity: :neutral,
                 base_salience: :none,
                 first_boundary: :none,
                 repeated_boundary: :none,
                 trust_delta_on_press: 0
               }
             },
             behaviors: [
               %{
                 trigger: :world_tick,
                 action: :send_message,
                 to: "npc_mira",
                 type: :rumor,
                 content: "Tobin quietly warned Mira that the mine road was watched.",
                 importance: 2,
                 tags: [:mine, :road, :tobin]
               }
             ]
           }
         },
         %{
           id: "npc_elin",
           name: "Elin",
           type: :npc,
           location: "loc_silent_mine",
           traits: %{role: "scout", temperament: "reckless"},
           metadata: %{
             topic_policies: %{
               weather: %{
                 track?: false,
                 sensitivity: :neutral,
                 base_salience: :none,
                 first_boundary: :none,
                 repeated_boundary: :none,
                 trust_delta_on_press: 0
               }
             }
           }
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
  Generates AI-assisted world blueprint text.

  This function uses the existing AI boundary and returns generated text only.
  It does not parse AI output, validate it as a blueprint, or spawn entities.
  """
  def generate_world_ai(prompt, opts \\ [])

  def generate_world_ai(prompt, opts) when is_binary(prompt) do
    ai_prompt = Procession.Generator.Prompt.world_blueprint(prompt)

    case Procession.AI.generate(ai_prompt, opts) do
      {:ok, response_text} ->
        {:ok,
         %{
           prompt: ai_prompt,
           response: response_text
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def generate_world_ai(_prompt, _opts) do
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
         :ok <- require_known_location_exits(blueprint),
         :ok <- require_known_relationship_entities(blueprint),
         :ok <- require_valid_starter_memories(blueprint),
         :ok <- require_valid_npc_behaviors(blueprint) do
      :ok
    end
  end

  def validate_blueprint(_blueprint) do
    {:error, :invalid_blueprint}
  end

  @doc """
  Spawns a validated world blueprint into live entity processes.

  Generation and spawning stay separate: `generate_world/2` creates data,
  while `spawn_world/1` starts processes from that data.
  """
  def spawn_world(blueprint) when is_map(blueprint) do
    with :ok <- validate_blueprint(blueprint),
         {:ok, location_ids} <- spawn_locations(blueprint.locations),
         {:ok, npc_ids} <- spawn_npcs(blueprint.npcs),
         {:ok, faction_ids} <- spawn_factions(blueprint.factions),
         :ok <- attach_relationships(blueprint.relationships),
         :ok <- attach_starter_memories(blueprint.starter_memories) do
      {:ok,
       %{
         locations: location_ids,
         npcs: npc_ids,
         factions: faction_ids,
         relationships: length(blueprint.relationships),
         starter_memories: length(blueprint.starter_memories)
       }}
    end
  end

  def spawn_world(_blueprint) do
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

  defp spawn_locations(locations) do
    spawn_entities(locations, fn location ->
      attrs =
        location
        |> Map.drop([:id, :exits])
        |> Map.put(:metadata, %{
          description: Map.get(location, :description),
          exits: Map.get(location, :exits, [])
        })

      Procession.EntitySupervisor.start_location(location.id, attrs)
    end)
  end

  defp spawn_npcs(npcs) do
    spawn_entities(npcs, fn npc ->
      attrs = Map.drop(npc, [:id])

      Procession.EntitySupervisor.start_npc(npc.id, attrs)
    end)
  end

  defp spawn_factions(factions) do
    spawn_entities(factions, fn faction ->
      attrs =
        faction
        |> Map.drop([:id])
        |> Map.put(:metadata, %{description: Map.get(faction, :description)})

      Procession.EntitySupervisor.start_faction(faction.id, attrs)
    end)
  end

  defp spawn_entities(entities, spawn_fun) do
    Enum.reduce_while(entities, {:ok, []}, fn entity, {:ok, ids} ->
      case spawn_fun.(entity) do
        {:ok, _pid} -> {:cont, {:ok, ids ++ [entity.id]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp attach_starter_memories(starter_memories) do
    Enum.reduce_while(starter_memories, :ok, fn memory, :ok ->
      message = %{
        type: Map.get(memory, :type, :memory),
        content: Map.get(memory, :content),
        importance: Map.get(memory, :importance, 1),
        tags: Map.get(memory, :tags, []),
        metadata: %{
          source: :generator
        }
      }

      case Procession.Entity.send_to("system_generator", memory.entity_id, message) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp attach_relationships(relationships) do
    Enum.reduce_while(relationships, :ok, fn relationship, :ok ->
      case Procession.Entity.get_state(relationship.from) do
        state ->
          existing_relationships = Map.get(state.metadata, :relationships, [])

          updated_relationships = [
            %{
              to: relationship.to,
              type: relationship.type,
              description: Map.get(relationship, :description)
            }
            | existing_relationships
          ]

          case Procession.Entity.set_metadata(
                 relationship.from,
                 :relationships,
                 updated_relationships
               ) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
      end
    end)
  end

  defp require_valid_npc_behaviors(blueprint) do
    case Enum.find_value(blueprint.npcs, &invalid_npc_behavior/1) do
      nil -> :ok
      {npc, behavior, reason} -> {:error, {:invalid_behavior, npc.id, behavior, reason}}
    end
  end

  defp require_known_location_exits(blueprint) do
    location_ids = Enum.map(blueprint.locations, & &1.id)

    case Enum.find_value(blueprint.locations, fn location ->
           exits = Map.get(location, :exits, [])

           cond do
             not is_list(exits) ->
               {location, exits, :exits_must_be_list}

             true ->
               Enum.find_value(exits, fn exit ->
                 cond do
                   not is_map(exit) ->
                     {location, exit, :exit_must_be_map}

                   Map.get(exit, :to) not in location_ids ->
                     {location, exit, :unknown_exit_destination}

                   Map.get(exit, :label) in [nil, ""] ->
                     {location, exit, :missing_exit_label}

                   true ->
                     nil
                 end
               end)
           end
         end) do
      nil ->
        :ok

      {location, exit, reason} ->
        {:error, {:invalid_location_exit, location.id, exit, reason}}
    end
  end

  defp invalid_npc_behavior(npc) do
    behaviors =
      npc
      |> Map.get(:metadata, %{})
      |> Map.get(:behaviors, [])

    cond do
      not is_list(behaviors) ->
        {npc, behaviors, :behaviors_must_be_list}

      true ->
        Enum.find_value(behaviors, fn behavior ->
          case Procession.Behavior.validate(behavior) do
            :ok -> nil
            {:error, reason} -> {npc, behavior, reason}
          end
        end)
    end
  end
end
