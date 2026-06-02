defmodule Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalScorer do
  @moduledoc """
  Deterministic validation and scoring for NPC interaction contrastive naturalness eval cases.

  Contrastive naturalness cases compare a worse response against a better response.
  This scorer does not call AI or attempt subjective judgment. It validates that
  each contrastive case is structurally usable for future preference evaluation,
  training export, or model comparison.
  """

  @type eval_case :: map()
  @type score_result :: %{
          passed: boolean(),
          failures: [map()]
        }

  @doc """
  Scores a contrastive naturalness eval case.

  A case passes when it contains:

  - an `id`
  - a `worse_response`
  - a `better_response`
  - different worse and better responses
  - at least one `preference_reasons` entry
  """
  @spec score(eval_case()) :: score_result()
  def score(eval_case) when is_map(eval_case) do
    failures =
      []
      |> check_required_string(eval_case, "id")
      |> check_required_string(eval_case, "worse_response")
      |> check_required_string(eval_case, "better_response")
      |> check_responses_differ(eval_case)
      |> check_preference_reasons(eval_case)
      |> Enum.reverse()

    %{
      passed: failures == [],
      failures: failures
    }
  end

  def score(_eval_case) do
    %{
      passed: false,
      failures: [
        %{
          code: :invalid_eval_input,
          message: "Contrastive naturalness eval scorer requires an eval case map."
        }
      ]
    }
  end

  @doc """
  Scores many contrastive naturalness eval cases.
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
              message: "Contrastive naturalness eval batch scoring requires a list of cases."
            }
          ]
        }
      ]
    }
  end

  defp check_required_string(failures, eval_case, field) do
    case Map.get(eval_case, field) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          [
            %{
              code: :blank_required_field,
              field: field,
              message: "Contrastive naturalness eval case has blank required field: #{field}"
            }
            | failures
          ]
        else
          failures
        end

      _other ->
        [
          %{
            code: :missing_required_field,
            field: field,
            message: "Contrastive naturalness eval case is missing required field: #{field}"
          }
          | failures
        ]
    end
  end

  defp check_responses_differ(failures, eval_case) do
    worse_response = Map.get(eval_case, "worse_response")
    better_response = Map.get(eval_case, "better_response")

    if is_binary(worse_response) and is_binary(better_response) and
         String.trim(worse_response) == String.trim(better_response) do
      [
        %{
          code: :responses_do_not_differ,
          message: "Contrastive naturalness eval case requires different worse and better responses."
        }
        | failures
      ]
    else
      failures
    end
  end

  defp check_preference_reasons(failures, eval_case) do
    reasons = Map.get(eval_case, "preference_reasons")

    cond do
      is_list(reasons) and Enum.any?(reasons, &valid_reason?/1) ->
        failures

      true ->
        [
          %{
            code: :missing_preference_reasons,
            message:
              "Contrastive naturalness eval case requires at least one preference reason."
          }
          | failures
        ]
    end
  end

  defp valid_reason?(reason) when is_binary(reason), do: String.trim(reason) != ""
  defp valid_reason?(_reason), do: false
end
