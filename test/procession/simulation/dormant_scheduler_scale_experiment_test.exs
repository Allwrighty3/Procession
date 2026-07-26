defmodule Procession.Simulation.DormantSchedulerScaleExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DormantSchedulerScaleExperiment

  test "reports exact bounded capacity and full fairness for a complete rotation" do
    result =
      DormantSchedulerScaleExperiment.run(
        populations: [4],
        budgets: [2],
        cadences: [1],
        ticks: 4
      )

    assert result.scope == :scheduler_only
    assert [scenario] = result.scenarios
    assert scenario.population == 4
    assert scenario.eligible_cycles == 4
    assert scenario.attempted == 8
    assert scenario.expected_capacity == 8
    assert scenario.capacity_utilization == 1.0
    assert scenario.population_coverage == 1.0
    assert scenario.never_selected == 0
    assert scenario.min_selections_among_served == 2
    assert scenario.max_selections == 2
    assert scenario.selection_spread == 0
    assert scenario.runtime_us >= 0
  end

  test "cadence reduces eligible cycles without changing the strict budget" do
    result =
      DormantSchedulerScaleExperiment.run(
        populations: [10],
        budgets: [3],
        cadences: [2],
        ticks: 5
      )

    assert [scenario] = result.scenarios
    assert scenario.eligible_cycles == 2
    assert scenario.attempted == 6
    assert scenario.expected_capacity == 6
    assert scenario.deferred_opportunities == 14
  end

  test "zero budget performs no service and remains numerically safe" do
    result =
      DormantSchedulerScaleExperiment.run(
        populations: [5],
        budgets: [0],
        cadences: [1],
        ticks: 3
      )

    assert [scenario] = result.scenarios
    assert scenario.attempted == 0
    assert scenario.expected_capacity == 0
    assert scenario.capacity_utilization == 0.0
    assert scenario.population_coverage == 0.0
    assert scenario.never_selected == 5
    assert scenario.selection_spread == 0
    assert scenario.runtime_us_per_attempt == 0.0
  end
end
