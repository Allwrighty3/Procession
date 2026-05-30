defmodule Procession.AI.DialogueRequest do
  @moduledoc """
  Structured request data for AI-backed NPC dialogue.

  This module does not call AI, mutate entities, or validate AI output.
  It only shapes already-validated simulation data into a clear dialogue request
  boundary that prompt builders and adapters can consume.
  """

  defstruct [
    :npc,
    :player_message,
    relevant_memories: [],
    location_context: nil,
    world_context: nil
  ]

  @type npc_context :: %{
          id: String.t(),
          name: String.t(),
          type: atom(),
          status: atom(),
          location: String.t() | atom() | nil,
          traits: map()
        }

  @type t :: %__MODULE__{
          npc: npc_context(),
          player_message: String.t(),
          relevant_memories: [map()],
          location_context: map() | nil,
          world_context: map() | nil
        }

  def from_entity_state(state, player_message, memories, opts \\ [])
      when is_binary(player_message) and is_list(memories) do
    {:ok,
     %__MODULE__{
       npc: %{
         id: state.id,
         name: state.name,
         type: state.type,
         status: state.status,
         location: state.location,
         traits: state.traits
       },
       player_message: player_message,
       relevant_memories: memories,
       location_context: Keyword.get(opts, :location_context),
       world_context: Keyword.get(opts, :world_context)
     }}
  end

  def from_entity_state(_state, _player_message, _memories, _opts) do
    {:error, :invalid_dialogue_request}
  end
end
