defmodule Procession.CLI do
  @moduledoc """
  Tiny local terminal loop for playing the deterministic Procession demo.

  This module owns terminal input/output only. It does not own gameplay rules,
  command parsing, ticking, travel, memory, or simulation state.
  """

  alias Procession.Command
  alias Procession.Command.Display
  alias Procession.GameSession

  @help_text """
  Commands:
  - look
  - where
  - look at Tobin
  - ask Tobin about road
  - talk to Tobin: Any news from the road?
  - wait
  - go to Briar Village
  - ask Mira about mine
  - events for Mira
  - help
  - quit
  """

  def play(prompt \\ "a quiet frontier town") do
    with {:ok, demo} <- GameSession.start_demo(prompt) do
      print_intro()
      print_current_location(demo.session)
      loop(demo.session)
    end
  end

  defp loop(session) do
    case IO.gets("> ") do
      nil ->
        quit(session)

      input ->
        input
        |> String.trim()
        |> handle_input(session)
    end
  end

  defp handle_input(input, session) do
    case String.downcase(input) do
      "" ->
        loop(session)

      "help" ->
        print_help()
        loop(session)

      "commands" ->
        print_help()
        loop(session)

      "where" ->
        print_current_location(session)
        loop(session)

      "quit" ->
        quit(session)

      "exit" ->
        quit(session)

      _ ->
        run_game_command(input, session)
    end
  end

  defp print_help do
    IO.puts(@help_text)
  end

  defp run_game_command(command_text, session) do
    session
    |> Command.run(command_text)
    |> Display.format()
    |> IO.puts()

    loop(session)
  end

  defp print_intro do
    IO.puts("""
    Procession local demo started.

    Type `help` for commands.
    Type `quit` to exit.
    """)
  end

  defp print_current_location(session) do
    session
    |> Command.run("look")
    |> Display.format()
    |> IO.puts()
  end

  defp quit(session) do
    cleanup_summary = GameSession.cleanup(session)

    IO.puts("""
    Demo cleaned up.
    Stopped entities: #{length(cleanup_summary.stopped)}
    Missing entities: #{length(cleanup_summary.missing)}
    Status: #{cleanup_summary.status}
    """)

    :ok
  end
end
