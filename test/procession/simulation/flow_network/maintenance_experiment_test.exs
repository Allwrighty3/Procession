defmodule Procession.Simulation.FlowNetwork.MaintenanceExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.FlowNetwork.MaintenanceExperiment

  test "replenishment permits the pattern to persist" do
    state =
      MaintenanceExperiment.run(
        ticks: 60,
        intake: fn tick -> if rem(tick, 2) == 0, do: 0.24, else: 0.0 end
      )

    assert state.persisted
    assert state.tick == 60
    assert state.maintenance_used > state.action_used
    assert state.total_intake > 0.0
  end

  test "without replenishment the same pattern eventually fails" do
    state = MaintenanceExperiment.run(ticks: 120, intake: fn _tick -> 0.0 end)

    refute state.persisted
    assert state.tick < 120
    assert state.integrity <= 0.12
  end

  test "report and ledger make missing emergence explicit" do
    state = MaintenanceExperiment.run(ticks: 5)
    report = MaintenanceExperiment.report(state)

    assert report =~ "pattern persisted"
    assert :cognition in MaintenanceExperiment.missing_couplings()
    assert :other_entities in MaintenanceExperiment.missing_couplings()
  end
end
