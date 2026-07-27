defmodule Procession.Simulation.LivingBriarObserverRunTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LivingBriar

  @tag :living_briar_observer_run
  test "emit canonical observer trace" do
    run = LivingBriar.run(ticks: 24, budget: 3, cadence: 1, seed: 41)

    IO.puts("LIVING_BRIAR_OBSERVER_BEGIN")
    IO.puts(LivingBriar.format(run))
    IO.inspect(run.summary, label: "summary", pretty: true)
    IO.puts("LIVING_BRIAR_OBSERVER_END")

    assert run.summary.failures == 0
    assert run.summary.archived_minds_committed?
  end
end
