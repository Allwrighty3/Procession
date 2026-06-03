defmodule Procession.AI.NPCInteraction.InteractionPipeline do
  @moduledoc """
  Runs the deterministic NPC interaction intent pipeline.

  This pipeline builds a grounded response intent, validates it, realizes a safe
  deterministic fallback, and can optionally validate candidate response text
  against the intent.

  It does not call AI, mutate simulation state, or execute gameplay behavior.
  """

  alias Procession.AI.NPCInteraction.ResponseIntentBuilder
  alias Procession.AI.NPCInteraction.ResponseRealizer
  alias Procession.AI.NPCInteraction.ResponseTextValidator

  @type pipeline_result ::
          {:ok,
           %{
             intent: map(),
             response: String.t(),
             response_source: :deterministic | :candidate,
             fallback_response: String.t(),
             validation_failures: [map()]
           }}
          | {:error, term()}

  @doc """
  Builds and realizes an NPC interaction response from grounded context.

  If `:candidate_response` is provided, the candidate is validated against the
  built response intent. Valid candidates are returned. Invalid candidates are
  rejected and the deterministic fallback response is returned instead.
  """
  @spec respond(map(), keyword()) :: pipeline_result()
  def respond(context, opts \\ [])

  def respond(context, opts) when is_map(context) and is_list(opts) do
    candidate_response = Keyword.get(opts, :candidate_response)

    with {:ok, intent} <- ResponseIntentBuilder.build(context),
         {:ok, fallback_response} <- ResponseRealizer.realize(intent) do
      choose_response(intent, fallback_response, candidate_response)
    end
  end

  def respond(_context, _opts), do: {:error, :invalid_interaction_context}

  defp choose_response(intent, fallback_response, nil) do
    {:ok,
     %{
       intent: intent,
       response: fallback_response,
       response_source: :deterministic,
       fallback_response: fallback_response,
       validation_failures: []
     }}
  end

  defp choose_response(intent, fallback_response, candidate_response)
       when is_binary(candidate_response) do
    case ResponseTextValidator.validate(intent, candidate_response) do
      {:ok, validated_response} ->
        {:ok,
         %{
           intent: intent,
           response: validated_response,
           response_source: :candidate,
           fallback_response: fallback_response,
           validation_failures: []
         }}

      {:error, failures} ->
        {:ok,
         %{
           intent: intent,
           response: fallback_response,
           response_source: :deterministic,
           fallback_response: fallback_response,
           validation_failures: failures
         }}
    end
  end

  defp choose_response(intent, fallback_response, _candidate_response) do
    {:ok,
     %{
       intent: intent,
       response: fallback_response,
       response_source: :deterministic,
       fallback_response: fallback_response,
       validation_failures: [
         %{
           code: :invalid_candidate_response,
           message: "Candidate response must be a string."
         }
       ]
     }}
  end
end
