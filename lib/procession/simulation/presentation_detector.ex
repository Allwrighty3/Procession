defmodule Procession.Simulation.PresentationDetector do
  @moduledoc """
  Tiny deterministic detector for converting player messages into field presentations.

  This is intentionally narrow scaffolding. It can use known people from the
  active scene, but it is not a full language-understanding system.
  """

  def from_player_message(message, opts \\ []) when is_binary(message) and is_list(opts) do
    known_people = Keyword.get(opts, :known_people, [])

    matched_person = find_known_person(message, known_people)

    %{
      source: "player",
      kind: infer_kind(message),
      target: infer_target(message, matched_person),
      target_name: person_name(matched_person),
      topic_key: infer_topic_key(message, matched_person),
      message_intent: infer_message_intent(message),
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
      true -> {:message, :general}
    end
  end

  defp person_name(%{name: name}) when is_binary(name), do: name
  defp person_name(_matched_person), do: nil

  defp infer_topic_key(_message, %{id: "npc_mira"}), do: :mira
  defp infer_topic_key(_message, %{id: "npc_tobin"}), do: :tobin

  defp infer_topic_key(message, _matched_person) do
    downcased = String.downcase(message)

    cond do
      String.contains?(downcased, "mira") -> :mira
      String.contains?(downcased, "tobin") -> :tobin
      true -> :general
    end
  end

  defp infer_message_intent(message) do
    downcased =
      message
      |> String.downcase()
      |> String.trim()

    cond do
      String.contains?(downcased, "who is mira") ->
        :ask_public_identity

      String.contains?(downcased, "who's mira") ->
        :ask_public_identity

      String.contains?(downcased, "is mira your sister") ->
        :ask_relationship_denial

      String.contains?(downcased, "is mira your brother") ->
        :ask_relationship_denial

      String.contains?(downcased, "where is mira") ->
        :ask_location

      String.contains?(downcased, "where can i find") and String.contains?(downcased, "mira") ->
        :ask_location

      true ->
        :general
    end
  end
end
