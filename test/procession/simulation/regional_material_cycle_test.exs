defmodule Procession.Simulation.RegionalMaterialCycleTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RegionalMaterialCycle

  test "gather, transformation, consumption, and transfer remain physically accounted" do
    state =
      RegionalMaterialCycle.new(
        loose_raw: 0.5,
        replenishment: 0.01,
        residents: [
          %{id: "a", energy: 0.8, usable: 0.2, gather_rate: 0.05, transform_rate: 0.03},
          %{id: "b", energy: 0.2, usable: 0.0, gather_rate: 0.02, transform_rate: 0.01}
        ]
      )

    before = RegionalMaterialCycle.total_material(state)
    {state, metrics} = RegionalMaterialCycle.step(state)
    after_total = RegionalMaterialCycle.total_material(state)

    assert metrics.gathered > 0
    assert metrics.transformed > 0
    assert metrics.consumed > 0
    assert metrics.transferred > 0
    assert_in_delta after_total, before + state.replenishment, 1.0e-9
  end
end
