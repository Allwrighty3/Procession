defmodule Procession.AI.NPCInteraction.ResponseIntentValidator do
  @moduledoc """
  Validates structured NPC interaction response intents.

  Response intents are inert data. They describe what an NPC response is allowed
  to mean before any natural language realization happens.

  This validator does not call AI, mutate simulation state, or execute gameplay
  behavior. It protects the boundary between grounded intent and surface speech.
  """

  @allowed_dialogue_acts [
    "answer_known_entity",
    "answer_self_identity",
    "answer_role_boundary",
    "express_uncertainty",
    "reject_false_relationship",
    "reject_false_role",
    "answer_known_location"
  ]

  @required_fields [
    "speaker_id",
    "target_id",
    "dialogue_act",
    "response_goal",
    "known_facts_used",
    "unknowns_acknowledged",
    "forbidden_inventions"
  ]

  @type response_intent :: map()

  @type validation_result ::
          {:ok, response_intent()}
          | {:error, [map()]}

  @doc """
  Validates a response intent map.

  Required properties:

  - `speaker_id` and `target_id` must be non-empty strings and must match
  - `dialogue_act` must be one of the allowed dialogue acts
  - `response_goal` must be a non-empty string
  - `known_facts_used`, `unknowns_acknowledged`, and `forbidden_inventions` must be lists
  """
  @spec validate(response_intent()) :: validation_result()
  def validate(intent) when is_map(intent) do
    failures =
      []
      |> check_required_fields(intent)
      |> check_non_empty_string(intent, "speaker_id")
      |> check_non_empty_string(intent, "target_id")
      |> check_speaker_matches_target(intent)
      |> check_dialogue_act(intent)
      |> check_non_empty_string(intent, "response_goal")
      |> check_list_field(intent, "known_facts_used")
      |> check_list_field(intent, "unknowns_acknowledged")
      |> check_list_field(intent, "forbidden_inventions")
      |> Enum.reverse()

    if failures == [] do
      {:ok, intent}
    else
      {:error, failures}
    end
  end

  def validate(_intent) do
    {:error,
     [
       %{
         code: :invalid_intent,
         message: "Response intent must be a map."
       }
     ]}
  end

  defp check_required_fields(failures, intent) do
    Enum.reduce(@required_fields, failures, fn field, acc ->
      if Map.has_key?(intent, field) do
        acc
      else
        [
          %{
            code: :missing_required_field,
            field: field,
            message: "Response intent is missing required field: #{field}"
          }
          | acc
        ]
      end
    end)
  end

  defp check_non_empty_string(failures, intent, field) do
    case Map.get(intent, field) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          [
            %{
              code: :blank_string_field,
              field: field,
              message: "Response intent field must not be blank: #{field}"
            }
            | failures
          ]
        else
          failures
        end

      _other ->
        [
          %{
            code: :invalid_string_field,
            field: field,
            message: "Response intent field must be a string: #{field}"
          }
          | failures
        ]
    end
  end

  defp check_speaker_matches_target(failures, intent) do
    speaker_id = Map.get(intent, "speaker_id")
    target_id = Map.get(intent, "target_id")

    if is_binary(speaker_id) and is_binary(target_id) and speaker_id != target_id do
      [
        %{
          code: :speaker_target_mismatch,
          speaker_id: speaker_id,
          target_id: target_id,
          message: "Response intent speaker_id must match target_id."
        }
        | failures
      ]
    else
      failures
    end
  end

  defp check_dialogue_act(failures, intent) do
    dialogue_act = Map.get(intent, "dialogue_act")

    cond do
      dialogue_act in @allowed_dialogue_acts ->
        failures

      is_binary(dialogue_act) ->
        [
          %{
            code: :unsupported_dialogue_act,
            dialogue_act: dialogue_act,
            allowed_dialogue_acts: @allowed_dialogue_acts,
            message: "Response intent has unsupported dialogue_act: #{dialogue_act}"
          }
          | failures
        ]

      true ->
        [
          %{
            code: :invalid_dialogue_act,
            message: "Response intent dialogue_act must be a string."
          }
          | failures
        ]
    end
  end

  defp check_list_field(failures, intent, field) do
    case Map.get(intent, field) do
      value when is_list(value) ->
        failures

      _other ->
        [
          %{
            code: :invalid_list_field,
            field: field,
            message: "Response intent field must be a list: #{field}"
          }
          | failures
        ]
    end
  end
end
