defmodule Procession.Command do
  @moduledoc """
  Deterministic text command boundary for player commands.

  This module translates simple command strings into existing session-aware
  gameplay APIs. It does not own gameplay logic.
  """

  alias Procession.GameSession

  @doc """
  Runs a deterministic player command against a game session.

  Command parsing is intentionally small and local. AI command interpretation,
  fuzzy matching, aliases, and CLI behavior are deferred.
  """
  def run(_session, command_text) when not is_binary(command_text) do
    {:error, :invalid_command}
  end

  def run(session, command_text) do
    command_text
    |> String.trim()
    |> parse()
    |> execute(session)
  end

  defp parse(""), do: {:error, :invalid_command}
  defp parse("look"), do: {:ok, :look}
  defp parse(_command), do: {:error, :unknown_command}

  defp execute({:ok, :look}, session) do
    case GameSession.perform(session, :look) do
      {:ok, result} ->
        {:ok, %{command: :look, result: result}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute({:error, reason}, _session), do: {:error, reason}
end
