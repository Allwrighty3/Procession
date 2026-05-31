defmodule Procession.AI.NPCInteraction.EvalScorer do
  @moduledoc """
  Deterministic scoring for NPC interaction eval cases.

  This module scores a provided response against an inert eval case.
  It does not call AI, mutate simulation state, or execute gameplay behavior.
  """

  @type eval_case :: map()
  @type response :: String.t()

  @type score_result :: %{
          passed: boolean(),
          failures: [map()]
        }

  @doc """
  Scores a response against an NPC interaction eval case.

  A response passes when:
  - every `must_include` string is present
  - at least one `must_include_any` string is present, unless the list is empty
  - no `must_not_include` string is present
  """
  @spec score(eval_case(), response()) :: score_result()
  def score(eval_case, response) when is_map(eval_case) and is_binary(response) do
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
  end

  def score(_eval_case, _response) do
    %{
      passed: false,
      failures: [
        %{
          code: :invalid_eval_input,
          message: "Eval scorer requires an eval case map and a response string."
        }
      ]
    }
  end

  @doc """
  Scores many eval cases against a map of provided responses.

  The response map should use eval case IDs as keys.
  """
  @spec score_cases([eval_case()], map()) :: %{
          total: non_neg_integer(),
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          results: [map()]
        }
  def score_cases(cases, responses_by_case_id)
      when is_list(cases) and is_map(responses_by_case_id) do
    results =
      Enum.map(cases, fn eval_case ->
        case_id = Map.get(eval_case, "id")
        response = Map.get(responses_by_case_id, case_id, "")

        score_result = score(eval_case, response)

        %{
          id: case_id,
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

  def score_cases(_cases, _responses_by_case_id) do
    %{
      total: 0,
      passed: 0,
      failed: 0,
      results: [
        %{
          id: nil,
          passed: false,
          failures: [
            %{
              code: :invalid_eval_batch_input,
              message: "Eval batch scoring requires a list of cases and a response map."
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
