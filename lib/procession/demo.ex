defmodule Procession.Demo do
  @moduledoc """
  IEx-friendly helpers for Procession's playable and observable vertical slices.

  This module does not own gameplay or simulation logic. It delegates compatibility play to
  `GameSession`, integrated living-world play to `LivingGameSession`, and standalone observation
  to `Procession.Simulation.LivingBriar`.
  """

  alias Procession.Command
  alias Procession.Command.Display
  alias Procession.GameSession
  alias Procession.LivingGameSession
  alias Procession.Simulation.LivingBriar

  @default_prompt "a quiet frontier town"

  @doc "Starts the deterministic starter-area compatibility demo session."
  def start(prompt \\ @default_prompt), do: GameSession.start_demo(prompt)

  @doc "Starts a playable starter session whose waits advance one stateful Living Briar world."
  def start_living(prompt \\ @default_prompt, opts \\ []) do
    LivingGameSession.start_demo(prompt, opts)
  end

  @doc "Starts the deterministic compatibility demo and returns only the session pid."
  def start_quiet(prompt \\ @default_prompt) do
    with {:ok, demo} <- start(prompt) do
      IO.puts("""
      Procession demo started.
      Compatibility mode uses the deterministic starter-area simulation.

      Try:
      - look
      - look at Tobin
      - ask Tobin about road
      - talk to Tobin: Any news from the road?
      - wait
      - go to Briar Village
      - look

      For integrated living-world play:
      - Procession.Demo.start_living_quiet()
      """)

      demo.session
    end
  end

  @doc "Starts integrated Living Briar play and returns only the session pid."
  def start_living_quiet(prompt \\ @default_prompt, opts \\ []) do
    with {:ok, demo} <- start_living(prompt, opts) do
      IO.puts("""
      Procession Living Briar session started.

      Ordinary commands still work. Each `wait` also advances the same stateful regional world.

      Try:
      - look
      - wait
      - wait
      - go to Briar Village
      - wait
      - Procession.GameSession.summary(session)
      """)

      demo.session
    end
  end

  @doc """
  Runs the canonical Living Briar scenario and returns structured observer evidence.

  The same boundary is used by tests and metrics. Options include `:ticks`, `:budget`,
  `:cadence`, and `:seed`.
  """
  def living_briar(opts \\ [])
  def living_briar(opts) when is_list(opts), do: LivingBriar.run(opts)
  def living_briar(_opts), do: {:error, :invalid_living_briar_options}

  @doc "Runs Living Briar, prints a compact causal trace, and returns the structured run."
  def watch_living_briar(opts \\ [])

  def watch_living_briar(opts) when is_list(opts) do
    run = LivingBriar.run(opts)
    IO.puts(LivingBriar.format(run))
    run
  end

  def watch_living_briar(_opts), do: {:error, :invalid_living_briar_options}

  @doc "Runs a command against a demo session and prints readable output."
  def run(demo_or_session, command_text) do
    with {:ok, session} <- session_from(demo_or_session) do
      session
      |> Command.run(command_text)
      |> Display.format()
      |> IO.puts()
    end
  end

  @doc "Runs a command against a demo session and returns the raw command result."
  def command(demo_or_session, command_text) do
    with {:ok, session} <- session_from(demo_or_session) do
      Command.run(session, command_text)
    end
  end

  @doc "Cleans up a demo session and prints a short cleanup summary."
  def stop(demo_or_session) do
    with {:ok, session} <- session_from(demo_or_session) do
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

  @doc "Runs a command and returns formatted text without printing it."
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
