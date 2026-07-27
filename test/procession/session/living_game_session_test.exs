defmodule Procession.LivingGameSessionTest do
  use ExUnit.Case, async: false

  alias Procession.Command
  alias Procession.GameSession
  alias Procession.LivingGameSession
  alias Procession.Simulation.LivingBriarRuntime

  test "wait advances one continuous Living Briar runtime" do
    {:ok, demo} = LivingGameSession.start_demo("a quiet frontier town", seed: 41, budget: 3)

    on_exit(fn ->
      if Process.alive?(demo.session), do: GameSession.cleanup(demo.session)
    end)

    assert {:ok, %{command: :wait, result: first}} = Command.run(demo.session, "wait")
    assert first.living_briar.tick == 1
    assert length(first.living_briar.decisions) == 3

    assert {:ok, %{command: :wait, result: second}} = Command.run(demo.session, "wait")
    assert second.living_briar.tick == 2
    assert length(second.living_briar.decisions) == 3

    summary = GameSession.summary(demo.session)
    assert summary.living_briar.tick == 2
    assert summary.living_briar.decisions == 6
    assert summary.living_briar.failures == 0
    assert summary.living_briar.archived_minds_committed?
  end

  test "ordinary starter-area commands remain available" do
    {:ok, demo} = LivingGameSession.start_demo()

    on_exit(fn ->
      if Process.alive?(demo.session), do: GameSession.cleanup(demo.session)
    end)

    assert {:ok, %{command: :look}} = Command.run(demo.session, "look")
    assert {:ok, %{command: :travel_to}} = Command.run(demo.session, "go to Briar Village")
    assert {:ok, %{command: :look}} = Command.run(demo.session, "look")
  end

  test "cleanup stops the stateful runtime and inner session entities" do
    {:ok, demo} = LivingGameSession.start_demo()
    runtime = :sys.get_state(demo.session).runtime

    assert Process.alive?(runtime)
    cleanup = GameSession.cleanup(demo.session)

    refute Process.alive?(runtime)
    assert cleanup.status == :cleaned_up
    assert cleanup.living_briar.tick == 0
  end

  test "runtime snapshot preserves material accounting across incremental steps" do
    {:ok, runtime} = LivingBriarRuntime.start_link(seed: 77, budget: 3, cadence: 1)

    on_exit(fn ->
      if Process.alive?(runtime), do: LivingBriarRuntime.stop(runtime)
    end)

    for expected_tick <- 1..12 do
      assert {:ok, observation} = LivingBriarRuntime.step(runtime)
      assert observation.tick == expected_tick
    end

    snapshot = LivingBriarRuntime.snapshot(runtime)
    assert snapshot.tick == 12
    assert snapshot.decisions == 36
    assert snapshot.failures == 0
    assert snapshot.archived_minds_committed?
    assert abs(snapshot.material_accounting_error) < 1.0e-8
  end
end
