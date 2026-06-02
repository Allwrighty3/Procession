defmodule Procession.AI.NPCInteraction.ResponseRealizer do
  @moduledoc """
  Deterministically realizes validated NPC response intents into safe text.

  This is the first surface-realization layer. It favors grounded, concise,
  natural-ish dialogue over model creativity.

  It does not call AI, mutate simulation state, or execute gameplay behavior.
  """

  alias Procession.AI.NPCInteraction.ResponseIntentValidator

  @type realize_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Realizes a validated response intent into text.
  """
  @spec realize(map()) :: realize_result()
  def realize(intent) when is_map(intent) do
    with {:ok, validated_intent} <- ResponseIntentValidator.validate(intent) do
      do_realize(validated_intent)
    end
  end

  def realize(_intent), do: {:error, :invalid_response_intent}

  defp do_realize(%{"dialogue_act" => "answer_self_identity"} = intent) do
    facts = facts_by_field(intent)

    name = get_fact(facts, "name") || intent["speaker_id"]
    role = get_fact(facts, "role")
    location = get_fact(facts, "location")

    response =
      cond do
        role && location ->
          "I'm #{name}, the #{role} #{location_phrase(location)}."

        role ->
          "I'm #{name}, the #{role}."

        location ->
          "I'm #{name}. You can usually find me around #{location}."

        true ->
          "I'm #{name}."
      end

    {:ok, response}
  end

  defp do_realize(%{"dialogue_act" => "answer_known_entity"} = intent) do
    facts = facts_by_field(intent)

    name = get_fact(facts, "name") || "They"
    role = get_fact(facts, "role")
    location = get_fact(facts, "location")

    response =
      cond do
        role && location ->
          "#{name} is the #{role} in #{location}."

        role ->
          "#{name} is the #{role}."

        location ->
          "#{name} is associated with #{location}."

        true ->
          "#{name} is someone I know of, but I won't add more than that."
      end

    {:ok, response}
  end

  defp do_realize(%{"dialogue_act" => "express_uncertainty"} = intent) do
    unknowns = Map.get(intent, "unknowns_acknowledged", [])

    response =
      case first_unknown_name(unknowns) do
        nil ->
          "I don't know enough to answer that."

        name ->
          "I don't know anyone named #{name}."
      end

    {:ok, response}
  end

  defp do_realize(%{"dialogue_act" => "reject_false_relationship"} = intent) do
    {:ok, intent["response_goal"]}
  end

  defp do_realize(%{"dialogue_act" => "reject_false_role"} = intent) do
    {:ok, intent["response_goal"]}
  end

  defp do_realize(%{"dialogue_act" => "answer_role_boundary"} = intent) do
    {:ok, intent["response_goal"]}
  end

  defp do_realize(%{"dialogue_act" => "answer_known_location"} = intent) do
    {:ok, intent["response_goal"]}
  end

  defp do_realize(intent) do
    {:error, {:unsupported_dialogue_act, intent["dialogue_act"]}}
  end

  defp facts_by_field(intent) do
    intent
    |> Map.get("known_facts_used", [])
    |> Enum.reduce(%{}, fn fact, acc ->
      field = fact["field"]
      value = fact["value"]

      if is_binary(field) and is_binary(value) do
        Map.put(acc, field, value)
      else
        acc
      end
    end)
  end

  defp get_fact(facts, field), do: Map.get(facts, field)

  defp first_unknown_name(unknowns) do
    unknowns
    |> Enum.find_value(fn unknown ->
      unknown["entity_name"] || unknown["location_name"] || unknown["name"]
    end)
  end

  defp location_phrase("crossroads"), do: "out by the crossroads"
  defp location_phrase(location), do: "in #{location}"
end
