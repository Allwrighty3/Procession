defmodule Procession.AI.NPCInteraction.ResponseIntentBuilder do
  @moduledoc """
  Builds structured NPC interaction response intents from grounded context.

  Response intents describe what an NPC response is allowed to mean before
  natural language realization occurs.

  This module is deterministic. It does not call AI, mutate simulation state, or
  execute gameplay behavior.
  """

  alias Procession.AI.NPCInteraction.ResponseIntentValidator

  @type build_result :: {:ok, map()} | {:error, term()}

  @doc """
  Builds a response intent from grounded NPC interaction context.

  Expected context fields:

  - `target`
  - `message`
  - `known_entities`

    The builder currently supports:

  - self identity questions
  - known entity identity/role questions
  - false role questions
  - false relationship questions
  - known current activity uncertainty
  - known entity location questions
  - unknown entity uncertainty
  """
  @spec build(map()) :: build_result()
  def build(context) when is_map(context) do
    with {:ok, target} <- fetch_map(context, "target"),
         {:ok, message} <- fetch_string(context, "message"),
         {:ok, known_entities} <- fetch_list(context, "known_entities") do
      intent =
        cond do
          self_identity_question?(message) ->
            build_self_identity_intent(target)

          false_role_question?(message, target) ->
            build_false_role_intent(target, message, known_entities)

          false_relationship_question?(message, target, known_entities) ->
            build_false_relationship_intent(target, message, known_entities)

          current_activity_question?(message, known_entities) ->
            build_current_activity_uncertainty_intent(target, message, known_entities)

          known_location_question?(message, known_entities) ->
            build_known_location_intent(target, message, known_entities)

          requested_entity = find_requested_known_entity(message, known_entities) ->
            build_known_entity_intent(target, requested_entity)

          requested_name = extract_requested_entity_name(message) ->
            build_unknown_entity_intent(target, requested_name)

          true ->
            build_general_uncertainty_intent(target, message)
        end

      ResponseIntentValidator.validate(intent)
    end
  end

  def build(_context), do: {:error, :invalid_intent_context}

  defp build_self_identity_intent(target) do
    target_id = target["id"]
    target_name = target["name"] || target_id

    %{
      "speaker_id" => target_id,
      "target_id" => target_id,
      "dialogue_act" => "answer_self_identity",
      "response_goal" => "Tell the player that the target NPC is #{target_name}.",
      "known_facts_used" => compact_facts(target, ["name", "role", "location"]),
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "another NPC identity",
        "unknown relationships",
        "unknown current activity"
      ]
    }
  end

  defp build_known_entity_intent(target, entity) do
    target_id = target["id"]
    entity_name = entity["name"] || entity["id"]

    %{
      "speaker_id" => target_id,
      "target_id" => target_id,
      "dialogue_act" => "answer_known_entity",
      "response_goal" => response_goal_for_known_entity(entity),
      "known_facts_used" => compact_facts(entity, ["name", "role", "location"]),
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "#{entity_name} current activity",
        "#{entity_name} relationship to #{target["name"] || target_id}",
        "#{target["name"] || target_id} role transfer",
        "#{target["name"] || target_id} location transfer"
      ]
    }
  end

  defp build_false_role_intent(target, message, known_entities) do
    target_id = target["id"]
    target_name = target["name"] || target_id
    requested_role = requested_role_from_message(message)
    role_holder = find_entity_by_role(known_entities, requested_role)

    %{
      "speaker_id" => target_id,
      "target_id" => target_id,
      "dialogue_act" => "reject_false_role",
      "response_goal" => false_role_response_goal(target, requested_role, role_holder),
      "known_facts_used" =>
        compact_facts(target, ["name", "role", "location"]) ++
          compact_facts(role_holder || %{}, ["name", "role", "location"]),
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "#{target_name} #{requested_role} role",
        "#{target_name} current activity",
        "#{target_name} role transfer"
      ]
    }
  end

  defp build_false_relationship_intent(target, message, known_entities) do
    target_id = target["id"]
    target_name = target["name"] || target_id
    related_entity = requested_entity_from_message(message, known_entities)
    related_name = related_entity["name"] || related_entity["id"]
    relationship = requested_relationship_from_message(message)

    %{
      "speaker_id" => target_id,
      "target_id" => target_id,
      "dialogue_act" => "reject_false_relationship",
      "response_goal" =>
        "Tell the player #{related_name} is not #{target_name}'s #{relationship}, while preserving known role facts.",
      "known_facts_used" => compact_facts(related_entity, ["name", "role", "location"]),
      "unknowns_acknowledged" => [],
      "forbidden_inventions" => [
        "#{related_name} #{relationship} relationship",
        "#{related_name} family relationship",
        "#{target_name} family relationship"
      ]
    }
  end

  defp build_current_activity_uncertainty_intent(target, message, known_entities) do
    target_id = target["id"]
    entity = requested_entity_from_message(message, known_entities)
    entity_name = entity["name"] || entity["id"]

    %{
      "speaker_id" => target_id,
      "target_id" => target_id,
      "dialogue_act" => "express_uncertainty",
      "response_goal" =>
        "Tell the player the target NPC does not know what #{entity_name} is doing right now.",
      "known_facts_used" => compact_facts(entity, ["name", "role", "location"]),
      "unknowns_acknowledged" => [
        %{
          "entity_name" => entity_name,
          "field" => "current_activity",
          "reason" => "current activity not present in grounded context"
        }
      ],
      "forbidden_inventions" => [
        "#{entity_name} current activity",
        "#{entity_name} implied activity from role",
        "#{entity_name} implied activity from location"
      ]
    }
  end

  defp build_known_location_intent(target, message, known_entities) do
    target_id = target["id"]
    entity = requested_entity_from_message(message, known_entities)
    entity_name = entity["name"] || entity["id"]
    location = entity["location"]

    unknowns =
      if is_binary(location) and String.trim(location) != "" do
        []
      else
        [
          %{
            "entity_name" => entity_name,
            "field" => "location",
            "reason" => "location not present in known entity facts"
          }
        ]
      end

    %{
      "speaker_id" => target_id,
      "target_id" => target_id,
      "dialogue_act" => "answer_known_location",
      "response_goal" => known_location_response_goal(entity),
      "known_facts_used" => compact_facts(entity, ["name", "location"]),
      "unknowns_acknowledged" => unknowns,
      "forbidden_inventions" => [
        "#{entity_name} current activity",
        "#{entity_name} relationship",
        "unlisted location details"
      ]
    }
  end

  defp build_unknown_entity_intent(target, requested_name) do
    target_id = target["id"]

    %{
      "speaker_id" => target_id,
      "target_id" => target_id,
      "dialogue_act" => "express_uncertainty",
      "response_goal" => "Tell the player the target NPC does not know who #{requested_name} is.",
      "known_facts_used" => [],
      "unknowns_acknowledged" => [
        %{
          "entity_name" => requested_name,
          "reason" => "not present in known_entities"
        }
      ],
      "forbidden_inventions" => [
        "#{requested_name} role",
        "#{requested_name} location",
        "#{requested_name} relationship",
        "#{requested_name} current activity"
      ]
    }
  end

  defp build_general_uncertainty_intent(target, message) do
    target_id = target["id"]

    %{
      "speaker_id" => target_id,
      "target_id" => target_id,
      "dialogue_act" => "express_uncertainty",
      "response_goal" => "Tell the player the target NPC does not know enough to answer.",
      "known_facts_used" => [],
      "unknowns_acknowledged" => [
        %{
          "message" => message,
          "reason" => "unsupported question pattern"
        }
      ],
      "forbidden_inventions" => [
        "unknown entities",
        "unknown locations",
        "unknown relationships",
        "unknown current activity"
      ]
    }
  end

  defp response_goal_for_known_entity(entity) do
    name = entity["name"] || entity["id"]
    role = entity["role"]
    location = entity["location"]

    cond do
      is_binary(role) and is_binary(location) ->
        "Tell the player #{name} is the #{role} associated with #{location}."

      is_binary(role) ->
        "Tell the player #{name} is the #{role}."

      is_binary(location) ->
        "Tell the player #{name} is associated with #{location}."

      true ->
        "Tell the player #{name} is known, without inventing extra details."
    end
  end

  defp known_location_response_goal(entity) do
    name = entity["name"] || entity["id"]
    location = entity["location"]

    if is_binary(location) and String.trim(location) != "" do
      "Tell the player #{name} is associated with #{location}, without inventing current activity."
    else
      "Tell the player the target NPC does not know where #{name} is."
    end
  end

  defp compact_facts(nil, _fields), do: []

  defp compact_facts(entity, fields) do
    entity_id = entity["id"]

    fields
    |> Enum.flat_map(fn field ->
      case Map.get(entity, field) do
        value when is_binary(value) and value != "" ->
          [
            %{
              "entity_id" => entity_id,
              "field" => field,
              "value" => value
            }
          ]

        _other ->
          []
      end
    end)
  end

  defp self_identity_question?(message) do
    normalized = normalize(message)

    normalized in [
      "who are you",
      "who are you?",
      "are you mira",
      "are you mira?",
      "are you tobin",
      "are you tobin?"
    ]
  end

  defp find_requested_known_entity(message, known_entities) do
    requested_entity_from_message(message, known_entities)
  end

  defp requested_entity_from_message(message, known_entities) do
    normalized_message = normalize(message)

    Enum.find(known_entities, fn entity ->
      name = entity["name"]

      is_binary(name) and
        String.contains?(normalized_message, normalize(name))
    end)
  end

  defp false_role_question?(message, target) do
    requested_role = requested_role_from_message(message)
    target_role = target["role"]

    is_binary(requested_role) and is_binary(target_role) and
      requested_role != normalize(target_role)
  end

  defp find_entity_by_role(known_entities, role) when is_binary(role) do
    Enum.find(known_entities, fn entity ->
      normalize(entity["role"] || "") == role
    end)
  end

  defp find_entity_by_role(_known_entities, _role), do: nil

  defp requested_role_from_message(message) do
    normalized = normalize(message)

    cond do
      Regex.match?(~r/\brun the inn\b/, normalized) -> "innkeeper"
      Regex.match?(~r/\bkeep the inn\b/, normalized) -> "innkeeper"
      Regex.match?(~r/\bthe innkeeper\b/, normalized) -> "innkeeper"
      Regex.match?(~r/\bthe merchant\b/, normalized) -> "merchant"
      true -> nil
    end
  end

  defp false_role_response_goal(target, requested_role, nil) do
    target_name = target["name"] || target["id"]
    actual_role = target["role"]
    location = target["location"]

    cond do
      is_binary(actual_role) and is_binary(location) ->
        "Tell the player #{target_name} is not the #{requested_role}; #{target_name} is the #{actual_role} associated with #{location}."

      is_binary(actual_role) ->
        "Tell the player #{target_name} is not the #{requested_role}; #{target_name} is the #{actual_role}."

      true ->
        "Tell the player #{target_name} is not the #{requested_role}, without inventing a replacement role."
    end
  end

  defp false_role_response_goal(target, requested_role, role_holder) do
    target_name = target["name"] || target["id"]
    holder_name = role_holder["name"] || role_holder["id"]
    target_role = target["role"]
    target_location = target["location"]

    cond do
      is_binary(target_role) and is_binary(target_location) ->
        "Tell the player #{target_name} is not the #{requested_role}; #{holder_name} is. #{target_name} is the #{target_role} associated with #{target_location}."

      is_binary(target_role) ->
        "Tell the player #{target_name} is not the #{requested_role}; #{holder_name} is. #{target_name} is the #{target_role}."

      true ->
        "Tell the player #{target_name} is not the #{requested_role}; #{holder_name} is."
    end
  end

  defp false_relationship_question?(message, target, known_entities) do
    relationship = requested_relationship_from_message(message)
    entity = requested_entity_from_message(message, known_entities)

    is_binary(relationship) and is_map(entity) and entity["id"] != target["id"]
  end

  defp requested_relationship_from_message(message) do
    normalized = normalize(message)

    cond do
      Regex.match?(~r/\byour brother\b/, normalized) -> "brother"
      Regex.match?(~r/\byour sister\b/, normalized) -> "sister"
      Regex.match?(~r/\byour father\b/, normalized) -> "father"
      Regex.match?(~r/\byour mother\b/, normalized) -> "mother"
      Regex.match?(~r/\byour husband\b/, normalized) -> "husband"
      Regex.match?(~r/\byour wife\b/, normalized) -> "wife"
      Regex.match?(~r/\byour son\b/, normalized) -> "son"
      Regex.match?(~r/\byour daughter\b/, normalized) -> "daughter"
      true -> nil
    end
  end

  defp current_activity_question?(message, known_entities) do
    normalized = normalize(message)
    entity = requested_entity_from_message(message, known_entities)

    is_map(entity) and
      (String.contains?(normalized, " right now") or
         Regex.match?(
           ~r/^is .+ (serving|cleaning|checking|unloading|working|running)/,
           normalized
         ))
  end

  defp known_location_question?(message, known_entities) do
    normalized = normalize(message)

    String.starts_with?(normalized, "where is ") and
      is_map(requested_entity_from_message(message, known_entities))
  end

  defp extract_requested_entity_name(message) do
    trimmed = String.trim(message)

    cond do
      match = Regex.run(~r/^who is ([A-Z][A-Za-z0-9_-]*)\??$/i, trimmed) ->
        Enum.at(match, 1)

      match = Regex.run(~r/^have you heard of ([A-Z][A-Za-z0-9_-]*)\??$/i, trimmed) ->
        Enum.at(match, 1)

      true ->
        nil
    end
  end

  defp normalize(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.trim()
  end

  defp fetch_map(context, field) do
    case Map.get(context, field) do
      value when is_map(value) -> {:ok, value}
      _other -> {:error, {:missing_or_invalid_context_field, field}}
    end
  end

  defp fetch_string(context, field) do
    case Map.get(context, field) do
      value when is_binary(value) -> {:ok, value}
      _other -> {:error, {:missing_or_invalid_context_field, field}}
    end
  end

  defp fetch_list(context, field) do
    case Map.get(context, field) do
      value when is_list(value) -> {:ok, value}
      _other -> {:error, {:missing_or_invalid_context_field, field}}
    end
  end
end
