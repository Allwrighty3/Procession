defmodule Procession.Simulation.RelationalSocialDevelopmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationalSocialDevelopmentExperiment, as: Experiment

  test "runs all memory and social conditions deterministically" do
    result = Experiment.run(population: 2, teaching_ticks: 24, transfer_ticks: 32, seed: 7)

    assert Map.keys(result.transfer) |> Enum.sort() == [:absolute, :relational]
    assert Map.keys(result.siblings) |> Enum.sort() == [:isolated, :signals, :visible]
    assert length(result.transfer_rows) == 4
    assert length(result.sibling_rows) == 6
    assert result == Experiment.run(population: 2, teaching_ticks: 24, transfer_ticks: 32, seed: 7)
  end

  test "report exposes the evidence categories" do
    report = Experiment.run(population: 1, teaching_ticks: 12, transfer_ticks: 16, seed: 9) |> Experiment.report()

    assert report =~ "MEMORY TRANSFER"
    assert report =~ "CONCURRENT LEARNER"
    assert report =~ "SIGNAL DETAIL"
    assert report =~ "audience_sensitivity="
  end
end
