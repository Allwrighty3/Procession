defmodule Procession.Simulation.CascadingRegionalChangeExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.CascadingRegionalChangeExperiment

  test "population movement changes later regional conditions without destination metadata" do
    result = CascadingRegionalChangeExperiment.run(ticks: 48, budget: 3, cadence: 1, seed: 41)

    assert result.destination_metadata_present? == false
    assert result.totals.failed == 0
    assert result.totals.attempted > 0
    assert result.analysis.dynamic_conditions_changed?
    assert result.analysis.population_changed?
    assert result.analysis.cascading_feedback_observed?
    assert map_size(result.snapshot_metrics) == 6
    assert result.live_entity_process_peak == 0
  end

  test "scheduler budget remains observable in the ecosystem" do
    constrained = CascadingRegionalChangeExperiment.run(ticks: 24, budget: 1, cadence: 4, seed: 41)

    assert constrained.totals.attempted <= 6
    assert constrained.totals.deferred > 0
    assert constrained.totals.failed == 0
  end
end
