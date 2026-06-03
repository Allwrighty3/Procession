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
  alias Procession.AI.NPCInteraction.ResponseExpressionPipeline

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
    candidate_response_provided? = Keyword.has_key?(opts, :candidate_response)
    candidate_response = Keyword.get(opts, :candidate_response)
    expression_adapter = Keyword.get(opts, :expression_adapter)

    with {:ok, intent} <- ResponseIntentBuilder.build(context),
         {:ok, fallback_response} <- ResponseRealizer.realize(intent) do
      cond do
        candidate_response_provided? ->
          choose_response(intent, fallback_response, candidate_response)

        expression_adapter ->
          express_response(intent, fallback_response, expression_adapter, opts)

        true ->
          choose_response(intent, fallback_response, nil)
      end
    end
  end

  def respond(_context, _opts), do: {:error, :invalid_interaction_context}

  defp express_response(intent, fallback_response, expression_adapter, opts) do
    expression_opts =
      opts
      |> Keyword.delete(:candidate_response)
      |> Keyword.delete(:expression_adapter)
      |> Keyword.put(:adapter, expression_adapter)

    case ResponseExpressionPipeline.express(intent, fallback_response, expression_opts) do
      {:ok, result} ->
        {:ok,
         %{
           intent: intent,
           response: result.response,
           response_source: result.response_source,
           fallback_response: result.fallback_response,
           validation_failures: result.validation_failures,
           expression_prompt: result.prompt,
           expression_candidate_response: result.candidate_response,
           expression_adapter_error: result.adapter_error
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp choose_response(intent, fallback_response, nil) do
    {:ok,
     %{
       intent: intent,
       response: fallback_response,
       response_source: :deterministic,
       fallback_response: fallback_response,
       validation_failures: [],
       expression_prompt: nil,
       expression_candidate_response: nil,
       expression_adapter_error: nil
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
           validation_failures: [],
           expression_prompt: nil,
           expression_candidate_response: nil,
           expression_adapter_error: nil
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
           message: "Candidate response must be a string.",
           expression_prompt: nil,
           expression_candidate_response: nil,
           expression_adapter_error: nil
         }
       ]
     }}
  end
end
