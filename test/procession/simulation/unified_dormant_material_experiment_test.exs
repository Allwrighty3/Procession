defmodule Procession.Simulation.UnifiedDormantMaterialExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.UnifiedDormantMaterialExperiment

  test "archived minds produce and persist low-level material consequences" do
    result = UnifiedDormantMaterialExperiment.run(ticks: 48, budget: 3, cadence: 1, seed: 41)

    assert result.totals.decisions > 0
    assert result.totals.failures == 0
    assert result.analysis.archived_minds_committed?
    assert result.analysis.material_primitives_observed?
    assert result.analysis.pressure_changed?
    assert_in_delta result.material_accounting_error, 0.0, 1.0e-8
  end

  test "bounded cadence defers minds without stopping physical replenishment" do
    result = UnifiedDormantMaterialExperiment.run(ticks: 48, budget: 1, cadence: 4, seed: 41)

    assert result.totals.decisions <= 12
    assert result.totals.deferred > 0
    assert result.totals.failures == 0
    assert_in_delta result.material_accounting_error, 0.0, 1.0e-8
  end
end
