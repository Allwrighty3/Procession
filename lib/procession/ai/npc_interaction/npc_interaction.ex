defmodule Procession.AI.NPCInteraction do
  @moduledoc """
  Task-specific AI skill boundary for grounded NPC interaction.

  This module turns validated, authoritative dialogue context into an AI request.
  It does not mutate entity state, memory, behavior metadata, or world state.
  """

  alias Procession.AI
  alias Procession.AI.Prompt

  @type context :: map()
  @type result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Generates bounded NPC dialogue from grounded dialogue context.

  The context must already be built from authoritative simulation state.
  """
  @spec generate_response(context(), keyword()) :: result()
  def generate_response(context, opts \\ [])

  def generate_response(context, opts) when is_map(context) and is_list(opts) do
    context
    |> Prompt.grounded_npc_response()
    |> AI.generate(ai_adapter_opts(opts))
  end

  def generate_response(_context, _opts) do
    {:error, :invalid_npc_interaction_context}
  end

  defp ai_adapter_opts(opts) do
    Keyword.drop(opts, [
      :recent_count,
      :minimum_importance,
      :speaker,
      :location_context,
      :world_context,
      :timeout,
      :dialogue_context,
      :grounded_context,
      :memory_query
    ])
  end
end
