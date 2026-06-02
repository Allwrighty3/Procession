defmodule Procession.AI.NPCInteraction.InteractionPipeline do
  @moduledoc """
  Runs the deterministic NPC interaction intent pipeline.

  This pipeline builds a grounded response intent, validates it, and realizes it
  into safe text.

  It does not call AI, mutate simulation state, or execute gameplay behavior.
  """

  alias Procession.AI.NPCInteraction.ResponseIntentBuilder
  alias Procession.AI.NPCInteraction.ResponseRealizer

  @type pipeline_result ::
          {:ok,
           %{
             intent: map(),
             response: String.t()
           }}
          | {:error, term()}

  @doc """
  Builds and realizes a deterministic NPC interaction response from grounded context.
  """
  @spec respond(map()) :: pipeline_result()
  def respond(context) when is_map(context) do
    with {:ok, intent} <- ResponseIntentBuilder.build(context),
         {:ok, response} <- ResponseRealizer.realize(intent) do
      {:ok,
       %{
         intent: intent,
         response: response
       }}
    end
  end

  def respond(_context), do: {:error, :invalid_interaction_context}
end
