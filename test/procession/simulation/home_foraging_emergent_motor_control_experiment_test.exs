defmodule Procession.Simulation.HomeForagingEmergentMotorControlExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.HomeForagingEmergentMotorControlExperiment, as: Experiment

  test "no-teacher learners lack mature foraging competence" do
    result = Experiment.run(population: 8, seed: 11, max_ticks: 160)
    summary = result.summary

    assert length(result.rows) == 8
    assert summary.survived == 0
    assert summary.consumed == 0
    assert summary.collected == 0
    assert summary.median_death_tick < 160
    assert summary.stable_patterns < 1.0
  end

  test "report exposes developmental motor milestones" do
    report = Experiment.run(population: 2, seed: 5, max_ticks: 40) |> Experiment.report()

    assert report =~ "Emergent-movement no-teacher developmental control"
    assert report =~ "median_first_displacement"
    assert report =~ "stable_patterns"
    assert report =~ "strongest_coordination"
  end
end
