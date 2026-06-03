defmodule Procession.AI.NPCInteraction.ResponseExpressionPipeline do
  @moduledoc """
  Runs supervised NPC response expression.

  This pipeline renders an expression prompt from a validated response intent and
  deterministic fallback, asks an adapter for candidate text, then validates the
  candidate against the original intent.

  If the candidate is invalid or the adapter fails, the deterministic fallback is
  returned.

  This module does not mutate simulation state or execute gameplay behavior.
  """

  alias Procession.AI
  alias Procession.AI.NPCInteraction.ResponseExpressionPrompt
  alias Procession.AI.NPCInteraction.ResponseTextValidator
  alias Procession.AI.NPCInteraction.ResponseCandidateCleaner

  @type expression_result ::
          {:ok,
           %{
             response: String.t(),
             response_source: :expression_candidate | :deterministic,
             fallback_response: String.t(),
             prompt: String.t() | nil,
             candidate_response: String.t() | nil,
             validation_failures: [map()],
             adapter_error: term() | nil
           }}
          | {:error, term()}

  @doc """
  Runs supervised expression for an intent and deterministic fallback.

  Options are passed to `Procession.AI.generate/2`, so callers can provide
  adapters such as `Procession.AI.FakeAdapter` or `Procession.AI.Ollama`.
  """
  @spec express(map(), String.t(), keyword()) :: expression_result()
  def express(intent, fallback_response, opts \\ [])

  def express(intent, fallback_response, opts)
      when is_map(intent) and is_binary(fallback_response) and is_list(opts) do
    with {:ok, prompt} <- ResponseExpressionPrompt.render(intent, fallback_response) do
      prompt
      |> AI.generate(opts)
      |> handle_candidate(intent, fallback_response, prompt)
    end
  end

  def express(_intent, _fallback_response, _opts) do
    {:error, :invalid_expression_pipeline_input}
  end

  defp handle_candidate({:ok, candidate_response}, intent, fallback_response, prompt)
       when is_binary(candidate_response) do
    cleaned_candidate_response = ResponseCandidateCleaner.clean(candidate_response)

    case ResponseTextValidator.validate(intent, cleaned_candidate_response) do
      {:ok, validated_response} ->
        {:ok,
         %{
           response: validated_response,
           response_source: :expression_candidate,
           fallback_response: fallback_response,
           prompt: prompt,
           candidate_response: cleaned_candidate_response,
           validation_failures: [],
           adapter_error: nil
         }}

      {:error, failures} ->
        {:ok,
         %{
           response: fallback_response,
           response_source: :deterministic,
           fallback_response: fallback_response,
           prompt: prompt,
           candidate_response: cleaned_candidate_response,
           validation_failures: failures,
           adapter_error: nil
         }}
    end
  end

  defp handle_candidate({:ok, candidate_response}, _intent, fallback_response, prompt) do
    {:ok,
     %{
       response: fallback_response,
       response_source: :deterministic,
       fallback_response: fallback_response,
       prompt: prompt,
       candidate_response: inspect(candidate_response),
       validation_failures: [
         %{
           code: :invalid_expression_candidate,
           message: "Expression candidate must be a string."
         }
       ],
       adapter_error: nil
     }}
  end

  defp handle_candidate({:error, reason}, _intent, fallback_response, prompt) do
    {:ok,
     %{
       response: fallback_response,
       response_source: :deterministic,
       fallback_response: fallback_response,
       prompt: prompt,
       candidate_response: nil,
       validation_failures: [],
       adapter_error: reason
     }}
  end
end
