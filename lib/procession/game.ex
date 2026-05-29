defmodule Procession.Game do
  @moduledoc """
  Public gameplay boundary for player-facing inspection and actions.

  This module should orchestrate existing systems without owning long-lived state.
  Start with plain function calls before adding command parsing, LiveView, or
  stateful gameplay processes.
  """

  alias Procession.Entity
  alias Procession.EntitySupervisor

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
end
