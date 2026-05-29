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
           decription:
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
             "A loose band of locals who keep the roads safe when they can and prfitable when they cannot."
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
end
