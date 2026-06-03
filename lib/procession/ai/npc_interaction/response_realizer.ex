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
      cond do
        current_activity_unknown?(unknowns) ->
          current_activity_uncertainty_response(intent)

        name = first_unknown_name(unknowns) ->
          "I don't know anyone named #{name}."

        true ->
          "I don't know enough to answer that."
      end

    {:ok, response}
  end

  defp do_realize(%{"dialogue_act" => "reject_false_relationship"} = intent) do
    facts = facts_by_field(intent)

    name = get_fact(facts, "name") || "They"
    role = get_fact(facts, "role")
    location = get_fact(facts, "location")

    response =
      cond do
        role && location ->
          "No, #{name} isn't family. #{name} is the #{role} in #{location}."

        role ->
          "No, #{name} isn't family. #{name} is the #{role}."

        location ->
          "No, #{name} isn't family. #{name} is associated with #{location}."

        true ->
          "No, #{name} isn't family."
      end

    {:ok, response}
  end

  defp do_realize(%{"dialogue_act" => "reject_false_role"} = intent) do
    facts = Map.get(intent, "known_facts_used", [])

    target_facts =
      facts
      |> facts_for_entity(intent["speaker_id"])
      |> facts_list_by_field()

    role_holder_facts =
      facts
      |> Enum.reject(fn fact -> fact["entity_id"] == intent["speaker_id"] end)
      |> facts_list_by_field()

    speaker_name = get_fact(target_facts, "name") || intent["speaker_id"]
    speaker_role = get_fact(target_facts, "role")
    speaker_location = get_fact(target_facts, "location")

    holder_name = get_fact(role_holder_facts, "name")
    holder_role = get_fact(role_holder_facts, "role")

    response =
      cond do
        holder_name && holder_role && speaker_role && speaker_location ->
          "No, #{holder_name} is the #{holder_role}. I'm #{speaker_name}, the #{speaker_role} #{location_phrase(speaker_location)}."

        holder_name && holder_role && speaker_role ->
          "No, #{holder_name} is the #{holder_role}. I'm #{speaker_name}, the #{speaker_role}."

        speaker_role && speaker_location ->
          "No, I'm #{speaker_name}, the #{speaker_role} #{location_phrase(speaker_location)}."

        speaker_role ->
          "No, I'm #{speaker_name}, the #{speaker_role}."

        true ->
          "No, that's not my role."
      end

    {:ok, response}
  end

  defp do_realize(%{"dialogue_act" => "answer_role_boundary"} = intent) do
    {:ok, intent["response_goal"]}
  end

  defp do_realize(%{"dialogue_act" => "answer_known_location"} = intent) do
    facts = facts_by_field(intent)

    name = get_fact(facts, "name") || "They"
    location = get_fact(facts, "location")

    response =
      if location do
        pronoun = pronoun_for(name)

        "#{name} is associated with #{location}. I don't know where #{pronoun} #{present_tense_be_for(pronoun)} right now."
      else
        "I don't know where #{name} is."
      end

    {:ok, response}
  end

  defp facts_by_field(intent) do
    intent
    |> Map.get("known_facts_used", [])
    |> facts_list_by_field()
  end

  defp facts_list_by_field(facts) do
    Enum.reduce(facts, %{}, fn fact, acc ->
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

  defp facts_for_entity(facts, entity_id) do
    Enum.filter(facts, fn fact ->
      fact["entity_id"] == entity_id
    end)
  end

  defp pronoun_for(_name), do: "they"
  defp present_tense_be_for("they"), do: "are"
  defp present_tense_be_for(_pronoun), do: "is"

  defp current_activity_unknown?(unknowns) do
    Enum.any?(unknowns, fn unknown ->
      unknown["field"] == "current_activity"
    end)
  end

  defp current_activity_uncertainty_response(intent) do
    facts = facts_by_field(intent)

    name = get_fact(facts, "name") || first_unknown_name(intent["unknowns_acknowledged"]) || "they"
    role = get_fact(facts, "role")
    location = get_fact(facts, "location")

    known_fact_sentence =
      cond do
        role && location ->
          " #{name} is the #{role} #{location_phrase(location)}."

        role ->
          " #{name} is the #{role}."

        location ->
          " #{name} is associated with #{location}."

        true ->
          ""
      end

    "I don't know what #{name} is doing right now." <> known_fact_sentence
  end

  defp location_phrase("crossroads"), do: "out by the crossroads"
  defp location_phrase(location), do: "in #{location}"
end
