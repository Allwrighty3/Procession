defmodule Procession.Simulation.ActionCostReversalExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ActionCostReversalExperiment

  test "paired run is deterministic and balanced" do
    first = ActionCostReversalExperiment.run_many(Enum.to_list(1..5))
    second = ActionCostReversalExperiment.run_many(Enum.to_list(1..5))

    assert first == second
    assert Enum.count(first, &(&1.variant == :control)) == 5
    assert Enum.count(first, &(&1.variant == :action_cost)) == 5
  end

  test "control preserves neutral boundary lock while action cost creates negative events" do
    rows = ActionCostReversalExperiment.run_many(Enum.to_list(1..20))
    summary = ActionCostReversalExperiment.summarize(rows)

    assert summary.control.seeds == 20
    assert summary.action_cost.seeds == 20
    assert summary.action_cost.negative_events > summary.control.negative_events
    assert summary.action_cost.neutral_events < summary.control.neutral_events
  end
end
