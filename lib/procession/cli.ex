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
  - grounded talk to Tobin: Who is Mira?
  - wait
  - go to Briar Village
  - ask Mira about mine
  - events for Mira
  - commands
  - help
  - quit
  """

  def play(prompt \\ "a quiet frontier town", opts \\ []) do
    with {:ok, demo} <- GameSession.start_demo(prompt) do
      print_intro(opts)
      print_current_location(demo.session)
      loop(demo.session, opts)
    end
  end

  @doc """
  Starts the local demo with the Ollama adapter enabled.

  This keeps the normal demo fake-adapter safe while giving Phase 17 a visible,
  human-testable AI path.
  """
  def play_ai(prompt \\ "a quiet frontier town", opts \\ []) do
    ai_opts =
      opts
      |> Keyword.put_new(:adapter, Procession.AI.Ollama)

    play(prompt, ai_opts)
  end

  defp loop(session, opts) do
    case IO.gets("> ") do
      nil ->
        quit(session)

      input ->
        input
        |> String.trim()
        |> handle_input(session, opts)
    end
  end

  defp handle_input(input, session, opts) do
    case String.downcase(input) do
      "" ->
        loop(session, opts)

      "help" ->
        print_help()
        loop(session, opts)

      "commands" ->
        print_help()
        loop(session, opts)

      "where" ->
        print_current_location(session)
        loop(session, opts)

      "quit" ->
        quit(session)

      "exit" ->
        quit(session)

      _ ->
        run_game_command(input, session, opts)
    end
  end

  defp print_help do
    IO.puts(@help_text)
  end

  defp run_game_command(command_text, session, opts) do
    session
    |> Command.run(command_text, opts)
    |> Display.format()
    |> IO.puts()

    loop(session, opts)
  end

  defp print_intro(opts) do
    ai_mode =
      case Keyword.get(opts, :adapter) do
        Procession.AI.Ollama -> "AI dialogue: Ollama adapter enabled."
        nil -> "AI dialogue: deterministic fake adapter."
        adapter -> "AI dialogue: custom adapter #{inspect(adapter)}."
      end

    IO.puts("""
    Procession local demo started.
    #{ai_mode}

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
