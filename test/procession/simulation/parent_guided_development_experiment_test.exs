defmodule Procession.Simulation.ParentGuidedDevelopmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ParentGuidedDevelopmentExperiment, as: Experiment

  test "route memory accumulates before separation" do
    state = Experiment.run(ticks: 600, seed: 3, resource_regen: 0.002)

    assert map_size(state.child.route_memory) > 0
    assert state.parent_present
    assert state.child.alive
  end

  test "long runs preserve bounded world and child state" do
    state = Experiment.run(ticks: 1_500, seed: 4, resource_regen: 0.002)
    {x, y} = state.child.position

    assert x in 0..3
    assert y in 0..3
    assert state.child.energy >= 0.0
    assert state.child.energy <= 1.0
    assert state.child.fatigue >= 0.0
    assert Enum.all?(state.resources, fn {_position, amount} -> amount >= 0.0 end)
  end

  test "population comparison is deterministic" do
    opts = [ticks: 900, seeds: Enum.to_list(1..5), resource_regen: 0.002]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end

  test "render exposes age and learned state" do
    state = Experiment.run(ticks: 200, seed: 2, resource_regen: 0.002)
    rendered = Experiment.render(state)

    assert rendered =~ "age="
    assert rendered =~ "memory="
    assert rendered =~ "parent="
  end
end
