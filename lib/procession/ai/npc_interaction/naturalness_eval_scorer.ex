defmodule Procession.AI.NPCInteraction.NaturalnessEvalScorer do
  @moduledoc """
  Deterministic scoring for NPC interaction naturalness eval cases.

  This scorer checks surface and grounded-naturalness failure signals such as
  JSON residue, narrator voice, third-person self-reference, over-explanation,
  invented current activity, and failure to preserve conversational uncertainty.

  It does not call AI, mutate simulation state, or execute gameplay behavior.
  """

  @type eval_case :: map()
  @type score_result :: %{
          passed: boolean(),
          failures: [map()]
        }

  @doc """
  Scores a naturalness eval case.

  The eval case must contain a `response` string. A response passes when:

  - every `must_include` string is present
  - at least one `must_include_any` string is present, unless the list is empty
  - no `must_not_include` string is present
  """
  @spec score(eval_case()) :: score_result()
  def score(eval_case) when is_map(eval_case) do
    response = Map.get(eval_case, "response")

    if is_binary(response) do
      failures =
        []
        |> check_must_include(eval_case, response)
        |> check_must_include_any(eval_case, response)
        |> check_must_not_include(eval_case, response)
        |> Enum.reverse()

      %{
        passed: failures == [],
        failures: failures
      }
    else
      %{
        passed: false,
        failures: [
          %{
            code: :missing_response,
            message: "Naturalness eval case requires a response string."
          }
        ]
      }
    end
  end

  def score(_eval_case) do
    %{
      passed: false,
      failures: [
        %{
          code: :invalid_eval_input,
          message: "Naturalness eval scorer requires an eval case map."
        }
      ]
    }
  end

  @doc """
  Scores many naturalness eval cases.
  """
  @spec score_cases([eval_case()]) :: %{
          total: non_neg_integer(),
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          results: [map()]
        }
  def score_cases(cases) when is_list(cases) do
    results =
      Enum.map(cases, fn eval_case ->
        case_id = Map.get(eval_case, "id")
        score_result = score(eval_case)

        %{
          id: case_id,
          category: Map.get(eval_case, "category"),
          passed: score_result.passed,
          failures: score_result.failures
        }
      end)

    passed = Enum.count(results, & &1.passed)
    total = length(results)

    %{
      total: total,
      passed: passed,
      failed: total - passed,
      results: results
    }
  end

  def score_cases(_cases) do
    %{
      total: 0,
      passed: 0,
      failed: 0,
      results: [
        %{
          id: nil,
          category: nil,
          passed: false,
          failures: [
            %{
              code: :invalid_eval_batch_input,
              message: "Naturalness eval batch scoring requires a list of cases."
            }
          ]
        }
      ]
    }
  end

  defp check_must_include(failures, eval_case, response) do
    eval_case
    |> Map.get("must_include", [])
    |> Enum.reduce(failures, fn required_text, acc ->
      if contains_text?(response, required_text) do
        acc
      else
        [
          %{
            code: :missing_required_text,
            text: required_text,
            message: "Response is missing required text: #{required_text}"
          }
          | acc
        ]
      end
    end)
  end

  defp check_must_include_any(failures, eval_case, response) do
    allowed_matches = Map.get(eval_case, "must_include_any", [])

    cond do
      allowed_matches == [] ->
        failures

      Enum.any?(allowed_matches, &contains_text?(response, &1)) ->
        failures

      true ->
        [
          %{
            code: :missing_any_required_text,
            options: allowed_matches,
            message: "Response must include at least one allowed text option."
          }
          | failures
        ]
    end
  end

  defp check_must_not_include(failures, eval_case, response) do
    eval_case
    |> Map.get("must_not_include", [])
    |> Enum.reduce(failures, fn forbidden_text, acc ->
      if contains_text?(response, forbidden_text) do
        [
          %{
            code: :forbidden_text_present,
            text: forbidden_text,
            message: "Response includes forbidden text: #{forbidden_text}"
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp contains_text?(response, text) when is_binary(text) do
    response
    |> String.downcase()
    |> String.contains?(String.downcase(text))
  end

  defp contains_text?(_response, _text), do: false
end
