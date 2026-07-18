defmodule Procession.Simulation.ClosedGridWorldExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ClosedGridWorldExperiment, as: Experiment

  test "default world uses a 4x4 grid and three resources" do
    resources = Experiment.default_resources()
    assert length(resources) == 3

    assert Enum.all?(resources, fn resource ->
             {x, y} = resource.position
             x in 0..3 and y in 0..3
           end)
  end

  test "closed loop updates embodied and world state" do
    state = Experiment.run(ticks: 80, seed: 4, mode: :fatigue_only)

    assert state.tick > 0
    assert state.intake >= 0.0
    assert state.movement_cost >= 0.0
    assert state.fatigue >= 0.0
    assert Enum.sum(Map.values(state.action_counts)) == state.tick
    assert length(state.history) == state.tick
  end

  test "conditional mode retains local suppression state" do
    state = Experiment.run(ticks: 120, seed: 7, mode: :conditional_refractory)

    assert state.failed_outputs >= 0
    assert state.harmful_outputs >= 0
    assert Enum.all?(Map.values(state.suppression), &(&1 >= 0.0))
  end

  test "population comparison is repeatable for fixed seeds" do
    opts = [ticks: 100, seeds: Enum.to_list(1..10)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end

  test "render exposes the world for IEx inspection" do
    state = Experiment.run(ticks: 5, seed: 2)
    rendered = Experiment.render(state)

    assert rendered =~ "E"
    assert rendered =~ "energy="
    assert rendered |> String.split("\n") |> length() == 5
  end
end
