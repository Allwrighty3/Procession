defmodule Procession.Simulation.PresentationDetector do
  @moduledoc """
  Tiny deterministic detector for converting player messages into field presentations.

  This is intentionally narrow. It exists to connect command text to the
  internal field experiment without pretending to solve language understanding.
  """

  def from_player_message(message) when is_binary(message) do
    %{
      source: "player",
      kind: infer_kind(message),
      target: infer_target(message),
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

  defp infer_target(message) do
    message
    |> String.downcase()
    |> then(fn downcased ->
      cond do
        String.contains?(downcased, "mira") -> {:person, :mira}
        String.contains?(downcased, "tobin") -> {:person, :tobin}
        true -> {:message, :general}
      end
    end)
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
