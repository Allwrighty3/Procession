defmodule Procession.Simulation.ParentGuidedDevelopmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ParentGuidedDevelopmentExperiment, as: Experiment

  test "child accumulates route memory while carried and following" do
    state = Experiment.run(ticks: 600, seed: 3)

    assert map_size(state.child.route_memory) > 0
    assert state.parent_present
    assert state.child.alive
  end

  test "child acts independently after parent departure" do
    state = Experiment.run(ticks: 1_100, seed: 4)

    refute state.parent_present
    assert state.child.independent_moves > 0
    assert state.child.route_reuse > 0
  end

  test "some long-lived children reach resources independently" do
    states = Enum.map(1..8, &Experiment.run(ticks: 1_500, seed: &1))

    assert Enum.any?(states, fn state ->
             MapSet.size(state.child.independent_resource_visits) > 0
           end)
  end

  test "population comparison is deterministic" do
    opts = [ticks: 900, seeds: Enum.to_list(1..5)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end

  test "render exposes parent, child, age, and memory" do
    state = Experiment.run(ticks: 200, seed: 2)
    rendered = Experiment.render(state)

    assert rendered =~ "age="
    assert rendered =~ "memory="
    assert rendered =~ "parent="
  end
end
