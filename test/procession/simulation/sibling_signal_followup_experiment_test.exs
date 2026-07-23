defmodule Procession.Simulation.SiblingSignalFollowupExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.SiblingSignalFollowupExperiment, as: Experiment

  test "runs isolated, visible, and signal conditions deterministically" do
    result = Experiment.run(population: 2, teaching_ticks: 20, transfer_ticks: 40, seed: 5)

    assert Map.keys(result.summary) |> Enum.sort() == [:isolated, :signals, :visible]
    assert length(result.rows) == 6
    assert result == Experiment.run(population: 2, teaching_ticks: 20, transfer_ticks: 40, seed: 5)
  end

  test "signal condition records actual exploratory signal attempts" do
    result = Experiment.run(population: 2, teaching_ticks: 20, transfer_ticks: 80, seed: 11)

    assert result.summary.signals.signal_attempts > 0
    assert Experiment.report(result) =~ "follower has no target-bearing feature"
  end
end
