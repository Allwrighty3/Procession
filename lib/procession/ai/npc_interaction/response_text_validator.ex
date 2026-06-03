defmodule Procession.AI.NPCInteraction.ResponseTextValidator do
  @moduledoc """
  Validates realized or AI-generated NPC response text against a response intent.

  This module is a final safety gate for surface text. It does not call AI,
  mutate simulation state, or execute gameplay behavior.
  """

  alias Procession.AI.NPCInteraction.ResponseIntentValidator

  @type validation_result :: {:ok, String.t()} | {:error, [map()]}

  @prompt_residue_patterns [
    "###",
    "{",
    "}",
    "\"response\"",
    "\"dialogue_act\"",
    "Response:",
    "Context:",
    "Task:"
  ]

  @doc """
  Validates candidate response text against a structured response intent.
  """
  @spec validate(map(), String.t()) :: validation_result()
  def validate(intent, text) when is_map(intent) and is_binary(text) do
    with {:ok, validated_intent} <- ResponseIntentValidator.validate(intent) do
      failures =
        []
        |> check_non_empty_text(text)
        |> check_prompt_residue(text)
        |> check_wrong_speaker_identity(validated_intent, text)
        |> check_forbidden_inventions(validated_intent, text)
        |> check_unknown_trait_invention(validated_intent, text)
        |> Enum.reverse()

      if failures == [] do
        {:ok, text}
      else
        {:error, failures}
      end
    end
  end

  def validate(_intent, _text) do
    {:error,
     [
       %{
         code: :invalid_response_text_validation_input,
         message: "Response text validation requires an intent map and response text string."
       }
     ]}
  end

  defp check_non_empty_text(failures, text) do
    if String.trim(text) == "" do
      [
        %{
          code: :blank_response_text,
          message: "Response text must not be blank."
        }
        | failures
      ]
    else
      failures
    end
  end

  defp check_prompt_residue(failures, text) do
    residue =
      Enum.find(@prompt_residue_patterns, fn pattern ->
        String.contains?(text, pattern)
      end)

    if residue do
      [
        %{
          code: :prompt_residue,
          residue: residue,
          message: "Response text contains prompt or structured-output residue."
        }
        | failures
      ]
    else
      failures
    end
  end

  defp check_wrong_speaker_identity(failures, intent, text) do
    speaker_name = speaker_name(intent)
    lower_text = String.downcase(text)

    cond do
      speaker_name == nil ->
        failures

      String.contains?(lower_text, "i'm ") and
          not String.contains?(lower_text, "i'm #{String.downcase(speaker_name)}") ->
        [
          %{
            code: :wrong_speaker_identity,
            speaker_name: speaker_name,
            message: "Response text appears to claim the wrong speaker identity."
          }
          | failures
        ]

      String.contains?(lower_text, "i am ") and
          not String.contains?(lower_text, "i am #{String.downcase(speaker_name)}") ->
        [
          %{
            code: :wrong_speaker_identity,
            speaker_name: speaker_name,
            message: "Response text appears to claim the wrong speaker identity."
          }
          | failures
        ]

      true ->
        failures
    end
  end

  defp check_forbidden_inventions(failures, intent, text) do
    forbidden = Map.get(intent, "forbidden_inventions", [])
    lower_text = String.downcase(text)

    forbidden
    |> Enum.reduce(failures, fn forbidden_item, acc ->
      if forbidden_item_appears?(forbidden_item, lower_text) do
        [
          %{
            code: :forbidden_invention,
            forbidden_invention: forbidden_item,
            message: "Response text appears to include a forbidden invention."
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp check_unknown_trait_invention(failures, intent, text) do
    lower_text = String.downcase(text)

    intent
    |> Map.get("unknowns_acknowledged", [])
    |> Enum.reduce(failures, fn unknown, acc ->
      entity_name = unknown["entity_name"]

      if is_binary(entity_name) do
        lower_name = String.downcase(entity_name)

        cond do
          String.contains?(lower_text, "#{lower_name} is a ") or
              String.contains?(lower_text, "#{lower_name} is the ") ->
            [
              %{
                code: :unknown_trait_invention,
                entity_name: entity_name,
                message: "Response text assigns traits to an unknown entity."
              }
              | acc
            ]

          true ->
            acc
        end
      else
        acc
      end
    end)
  end

  defp forbidden_item_appears?(forbidden_item, lower_text) when is_binary(forbidden_item) do
    forbidden_item = String.downcase(forbidden_item)

    cond do
      String.ends_with?(forbidden_item, " current activity") ->
        current_activity_appears?(forbidden_item, lower_text)

      String.contains?(forbidden_item, " implied activity") ->
        implied_activity_appears?(forbidden_item, lower_text)

      String.ends_with?(forbidden_item, " role") ->
        role_invention_appears?(forbidden_item, lower_text)

      String.contains?(forbidden_item, " relationship") ->
        relationship_invention_appears?(forbidden_item, lower_text)

      String.contains?(forbidden_item, " location transfer") ->
        location_transfer_appears?(forbidden_item, lower_text)

      String.contains?(forbidden_item, " role transfer") ->
        role_transfer_appears?(forbidden_item, lower_text)

      true ->
        false
    end
  end

  defp forbidden_item_appears?(_forbidden_item, _lower_text), do: false

  defp current_activity_appears?(forbidden_item, lower_text) do
    name = String.replace_suffix(forbidden_item, " current activity", "")

    String.contains?(lower_text, name) and
      Regex.match?(
        ~r/\b(serving|working|running|cleaning|checking|unloading|traveling|waiting|standing|sleeping|eating|drinking)\b/,
        lower_text
      )
  end

  defp implied_activity_appears?(forbidden_item, lower_text) do
    [name | _rest] = String.split(forbidden_item, " ", parts: 2)

    String.contains?(lower_text, name) and
      Regex.match?(
        ~r/\b(serving|working|running|cleaning|checking|unloading|traveling|waiting|standing|sleeping|eating|drinking)\b/,
        lower_text
      )
  end

  defp role_invention_appears?(forbidden_item, lower_text) do
    forbidden_item
    |> String.replace_suffix(" role", "")
    |> phrase_tokens_present?(lower_text)
  end

  defp relationship_invention_appears?(forbidden_item, lower_text) do
    phrase =
      forbidden_item
      |> String.replace(" relationship", "")

    phrase_tokens_present?(phrase, lower_text) and
      not relationship_mention_is_denied?(phrase, lower_text)
  end

  defp location_transfer_appears?(forbidden_item, lower_text) do
    forbidden_item
    |> String.replace(" location transfer", "")
    |> phrase_tokens_present?(lower_text)
  end

  defp role_transfer_appears?(forbidden_item, lower_text) do
    forbidden_item
    |> String.replace(" role transfer", "")
    |> phrase_tokens_present?(lower_text)
  end

  defp relationship_mention_is_denied?(phrase, lower_text) do
    tokens = String.split(phrase, ~r/\s+/, trim: true)

    case tokens do
      [name, relationship | _rest] ->
        denied_relationship_patterns?(name, relationship, lower_text)

      _other ->
        false
    end
  end

  defp denied_relationship_patterns?(name, relationship, lower_text) do
    denial_patterns = [
      ~r/\bno\b.*\b#{Regex.escape(name)}\b.*\b#{Regex.escape(relationship)}\b/,
      ~r/\b#{Regex.escape(name)}\b.*\bnot\b.*\b#{Regex.escape(relationship)}\b/,
      ~r/\b#{Regex.escape(name)}\b.*\bisn't\b.*\b#{Regex.escape(relationship)}\b/,
      ~r/\b#{Regex.escape(name)}\b.*\bis not\b.*\b#{Regex.escape(relationship)}\b/,
      ~r/\b#{Regex.escape(name)}\b.*\bnot my\b.*\b#{Regex.escape(relationship)}\b/,
      ~r/\b#{Regex.escape(name)}\b.*\bmy #{Regex.escape(relationship)}\?.*\bnot a chance\b/,
      ~r/\b#{Regex.escape(name)}\?.*\bmy #{Regex.escape(relationship)}\?.*\bnot a chance\b/,
      ~r/\b#{Regex.escape(name)}\b.*\bmy #{Regex.escape(relationship)}\?.*\bhardly\b/
    ]

    Enum.any?(denial_patterns, fn pattern ->
      Regex.match?(pattern, lower_text)
    end)
  end

  defp phrase_tokens_present?(phrase, lower_text) do
    phrase
    |> String.split(~r/\s+/, trim: true)
    |> Enum.all?(fn token -> String.contains?(lower_text, token) end)
  end

  defp speaker_name(intent) do
    speaker_id = intent["speaker_id"]

    intent
    |> Map.get("known_facts_used", [])
    |> Enum.find_value(fn fact ->
      if fact["entity_id"] == speaker_id and fact["field"] == "name" do
        fact["value"]
      else
        nil
      end
    end)
  end
end
