defmodule Procession.Demo do
  @moduledoc """
  IEx-friendly helpers for the first playable vertical slice.

  This module does not own gameplay logic. It delegates setup to `GameSession`,
  command execution to `Command`, and readable output to `Command.Display`.
  """

  alias Procession.Command
  alias Procession.Command.Display
  alias Procession.GameSession

  @default_prompt "a quiet frontier town"

  @doc """
  Starts the deterministic Phase 13 demo session.
  """
  def start(prompt \\ @default_prompt) do
    GameSession.start_demo(prompt)
  end

  @doc """
  Starts the deterministic demo and returns only the session pid.

  This is the preferred IEx entry point when playing the vertical slice because it
  avoids printing the full startup summary map.
  """
  def start_quiet(prompt \\ @default_prompt) do
    with {:ok, demo} <- start(prompt) do
      IO.puts("""
      Procession demo started.

      Try:
      - look
      - look at Tobin
      - ask Tobin about road
      - talk to Tobin: Any news from the road?
      - wait
      - go to Briar Village
      - look
      - ask Mira about mine
      - events for Mira
      """)

      demo.session
    end
  end

  @doc """
  Runs a command against a demo session, prints readable output, and returns `:ok`.

  Accepts either the full demo map returned by `start/1` or the session pid.
  """
  def run(demo_or_session, command_text) do
    with {:ok, session} <- session_from(demo_or_session) do
      session
      |> Command.run(command_text)
      |> Display.format()
      |> IO.puts()
    end
  end

  @doc """
  Runs a command against a demo session and returns the raw command result.

  This is useful for debugging, tests, or inspecting the underlying data shape.
  """
  def command(demo_or_session, command_text) do
    with {:ok, session} <- session_from(demo_or_session) do
      Command.run(session, command_text)
    end
  end

  @doc """
  Runs a command and returns formatted text without printing it.

  Useful for tests or for callers that want to decide how to display output.
  """
  def text(demo_or_session, command_text) do
    with {:ok, session} <- session_from(demo_or_session) do
      session
      |> Command.run(command_text)
      |> Display.format()
    end
  end

  defp session_from(%{session: session}) when is_pid(session), do: {:ok, session}
  defp session_from(session) when is_pid(session), do: {:ok, session}
  defp session_from(_demo_or_session), do: {:error, :invalid_demo_session}
end
