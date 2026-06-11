defmodule Procession.Simulation.PresentationDetector do
  @moduledoc """
  Tiny deterministic detector for converting player messages into field presentations.

  This is intentionally narrow scaffolding. It can use known people from the
  active scene, but it is not a full language-understanding system.
  """

  def from_player_message(message, opts \\ []) when is_binary(message) and is_list(opts) do
    known_people = Keyword.get(opts, :known_people, [])

    matched_person = find_known_person(message, known_people)
    target_name = person_name(matched_person)
    target_public_facts = person_public_facts(matched_person)

    %{
      source: "player",
      kind: infer_kind(message),
      target: infer_target(message, matched_person),
      target_name: target_name,
      target_public_facts: target_public_facts,
      topic_key: infer_topic_key(message, matched_person),
      message_intent: infer_message_intent(message, target_name),
      text: message
    }
  end

  defp infer_kind(message) do
    if String.ends_with?(String.trim(message), "?") do
      :question
    else
      :statement
    end
  end

  defp find_known_person(message, known_people) do
    downcased = String.downcase(message)

    Enum.find(known_people, fn person ->
      name =
        person
        |> Map.get(:name, "")
        |> to_string()
        |> String.downcase()

      name != "" and String.contains?(downcased, name)
    end)
  end

  defp infer_target(_message, %{id: id}) when is_binary(id), do: {:person, id}

  defp infer_target(message, nil) do
    downcased = String.downcase(message)

    cond do
      String.contains?(downcased, "mira") -> {:person, :mira}
      String.contains?(downcased, "tobin") -> {:person, :tobin}
      String.contains?(downcased, "elin") -> {:person, :elin}
      String.contains?(downcased, "weather") -> {:topic, :weather}
      true -> {:message, :general}
    end
  end

  defp person_name(%{name: name}) when is_binary(name), do: name
  defp person_name(_matched_person), do: nil

  defp person_public_facts(%{public_facts: public_facts}) when is_map(public_facts) do
    public_facts
  end

  defp person_public_facts(_matched_person), do: %{}

  defp infer_topic_key(_message, %{id: "npc_mira"}), do: :mira
  defp infer_topic_key(_message, %{id: "npc_tobin"}), do: :tobin
  defp infer_topic_key(_message, %{id: "npc_elin"}), do: :elin

  defp infer_topic_key(message, _matched_person) do
    downcased = String.downcase(message)

    cond do
      String.contains?(downcased, "mira") -> :mira
      String.contains?(downcased, "tobin") -> :tobin
      String.contains?(downcased, "elin") -> :elin
      String.contains?(downcased, "weather") -> :weather
      true -> :general
    end
  end

  defp infer_message_intent(message, target_name) do
    downcased =
      message
      |> String.downcase()
      |> String.trim()

    target =
      target_name
      |> to_string()
      |> String.downcase()

    cond do
      asks_public_identity?(downcased, target) ->
        :ask_public_identity

      asks_relationship_denial?(downcased, target) ->
        :ask_relationship_denial

      asks_location?(downcased, target) ->
        :ask_location

      true ->
        :general
    end
  end

  defp asks_public_identity?(message, ""), do: asks_public_identity_fallback?(message)

  defp asks_public_identity?(message, target) do
    String.contains?(message, "who is #{target}") or
      String.contains?(message, "who's #{target}")
  end

  defp asks_public_identity_fallback?(message) do
    String.contains?(message, "who is mira") or
      String.contains?(message, "who's mira") or
      String.contains?(message, "who is tobin") or
      String.contains?(message, "who's tobin") or
      String.contains?(message, "who is elin") or
      String.contains?(message, "who's elin")
  end

  defp asks_relationship_denial?(message, ""), do: asks_relationship_denial_fallback?(message)

  defp asks_relationship_denial?(message, target) do
    family_terms = ["sister", "brother"]

    Enum.any?(family_terms, fn family_term ->
      String.contains?(message, "is #{target} your #{family_term}")
    end)
  end

  defp asks_relationship_denial_fallback?(message) do
    String.contains?(message, "is mira your sister") or
      String.contains?(message, "is mira your brother") or
      String.contains?(message, "is tobin your sister") or
      String.contains?(message, "is tobin your brother") or
      String.contains?(message, "is elin your sister") or
      String.contains?(message, "is elin your brother")
  end

  defp asks_location?(message, ""), do: asks_location_fallback?(message)

  defp asks_location?(message, target) do
    String.contains?(message, "where is #{target}") or
      (String.contains?(message, "where can i find") and String.contains?(message, target))
  end

  defp asks_location_fallback?(message) do
    String.contains?(message, "where is mira") or
      String.contains?(message, "where is tobin") or
      String.contains?(message, "where is elin") or
      (String.contains?(message, "where can i find") and
         (String.contains?(message, "mira") or
            String.contains?(message, "tobin") or
            String.contains?(message, "elin")))
  end
end
