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
end
