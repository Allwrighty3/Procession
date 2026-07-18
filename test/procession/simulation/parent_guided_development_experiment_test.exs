defmodule Procession.Simulation.ParentGuidedDevelopmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ParentGuidedDevelopmentExperiment, as: Experiment

  test "route memory accumulates before separation" do
    state = Experiment.run(ticks: 600, seed: 3, resource_regen: 0.002)

    assert map_size(state.child.route_memory) > 0
    assert state.parent_present
    assert state.child.alive
  end

  test "some children reuse learned routes independently" do
    states =
      Enum.map(1..8, fn seed ->
        Experiment.run(ticks: 1_200, seed: seed, resource_regen: 0.002)
      end)

    assert Enum.any?(states, fn state ->
             not state.parent_present and state.child.independent_moves > 0 and
               state.child.route_reuse > 0
           end)
  end

  test "some long-lived children reach resources independently" do
    states =
      Enum.map(1..8, fn seed ->
        Experiment.run(ticks: 1_500, seed: seed, resource_regen: 0.002)
      end)

    assert Enum.any?(states, fn state ->
             length(state.child.independent_resource_visits) > 0
           end)
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
