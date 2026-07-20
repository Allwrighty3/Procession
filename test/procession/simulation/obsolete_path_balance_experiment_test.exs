defmodule Procession.Simulation.ObsoletePathBalanceExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ObsoletePathBalanceExperiment

  test "diagnostic is deterministic and internally balanced" do
    first = ObsoletePathBalanceExperiment.run(seed: 7)
    second = ObsoletePathBalanceExperiment.run(seed: 7)

    assert first == second
    assert first.obsolete_actions >= first.obsolete_at_boundary
    assert first.reinforcement_events >= first.reinforcement_at_boundary
    assert first.contradiction_events >= first.contradiction_at_boundary

    assert first.obsolete_actions ==
             first.neutral_events + first.reinforcement_events + first.contradiction_events
  end

  test "summary covers every requested seed" do
    rows = ObsoletePathBalanceExperiment.run_many(seeds: 1..5)
    summary = ObsoletePathBalanceExperiment.summarize(rows)

    assert length(rows) == 5
    assert summary.seeds == 5

    assert summary.seeds_reinforcement_exceeds_contradiction +
             summary.seeds_contradiction_exceeds_reinforcement + summary.seeds_tied == 5
  end
end
