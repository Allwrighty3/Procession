defmodule Procession.LivingGameSessionEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Command
  alias Procession.Command.Display
  alias Procession.GameSession
  alias Procession.LivingGameSession

  @tag :living_game_session_evidence
  test "emit integrated ordinary-command trace" do
    {:ok, demo} = LivingGameSession.start_demo("a quiet frontier town", seed: 41, budget: 3)

    IO.puts("LIVING_GAME_SESSION_BEGIN")

    Enum.each(1..8, fn _ ->
      {:ok, command} = Command.run(demo.session, "wait")
      IO.puts(Display.format({:ok, command}))
      IO.puts("---")
    end)

    {:ok, travel} = Command.run(demo.session, "go to Briar Village")
    IO.puts(Display.format({:ok, travel}))

    Enum.each(1..8, fn _ ->
      {:ok, command} = Command.run(demo.session, "wait")
      IO.puts(Display.format({:ok, command}))
      IO.puts("---")
    end)

    summary = GameSession.summary(demo.session)
    IO.inspect(summary.living_briar, label: "living_summary", pretty: true, limit: :infinity)

    cleanup = GameSession.cleanup(demo.session)
    IO.inspect(cleanup, label: "cleanup", pretty: true)
    IO.puts("LIVING_GAME_SESSION_END")

    assert summary.living_briar.tick == 16
    assert summary.living_briar.decisions == 48
    assert summary.living_briar.failures == 0
    assert summary.living_briar.archived_minds_committed?
    assert abs(summary.living_briar.material_accounting_error) < 1.0e-8
    assert cleanup.status == :cleaned_up
  end
end
