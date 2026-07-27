defmodule Procession.Simulation.ResidentResourceCascadeExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.ResidentResourceCascadeExperiment

  test "resident material behavior changes regional pressure and population" do
    result = ResidentResourceCascadeExperiment.run(ticks: 96, budget: 3, cadence: 1, seed: 41)

    assert result.totals.gathered > 0
    assert result.totals.transformed > 0
    assert result.totals.consumed > 0
    assert result.totals.transferred > 0
    assert result.analysis.material_behavior_observed?
    assert result.analysis.interpersonal_transfer_observed?
    assert result.analysis.pressure_changed?
    assert result.analysis.population_changed?
    assert result.analysis.cascade_observed?
  end

  test "bounded cadence changes decision volume" do
    normal = ResidentResourceCascadeExperiment.run(ticks: 48, budget: 3, cadence: 1, seed: 41)
    constrained = ResidentResourceCascadeExperiment.run(ticks: 48, budget: 1, cadence: 4, seed: 41)

    assert constrained.totals.decisions < normal.totals.decisions
  end
end
