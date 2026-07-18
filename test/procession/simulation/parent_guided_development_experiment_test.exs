defmodule Procession.Simulation.ParentGuidedDevelopmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ParentGuidedDevelopmentExperiment, as: Experiment

  test "carried phase records parent-guided route memory" do
    state = Experiment.run(ticks: 120, seed: 3, resource_regen: 0.002)

    assert state.tick == 120
    assert state.parent_present
    assert map_size(state.child.route_memory) > 0
  end

  test "world state remains bounded during development" do
    state = Experiment.run(ticks: 300, seed: 4, resource_regen: 0.002)
    {x, y} = state.child.position

    assert x in 0..3
    assert y in 0..3
    assert state.child.energy >= 0.0
    assert state.child.energy <= 1.0
    assert Enum.all?(state.resources, fn {_position, amount} -> amount >= 0.0 end)
  end

  test "short population comparison is deterministic" do
    opts = [ticks: 240, seeds: Enum.to_list(1..3), resource_regen: 0.002]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end

  test "no-parent control starts without learned routes" do
    state =
      Experiment.run(
        ticks: 120,
        seed: 3,
        resource_regen: 0.002,
        parent_departure: 0,
        carry_until: 0
      )

    refute state.parent_present
    assert state.child.route_memory == %{}
    assert state.child.independent_intake == 0.0
  end

  test "render exposes developmental state" do
    state = Experiment.run(ticks: 80, seed: 2, resource_regen: 0.002)
    rendered = Experiment.render(state)

    assert rendered =~ "age="
    assert rendered =~ "memory="
    assert rendered =~ "parent="
  end
end
