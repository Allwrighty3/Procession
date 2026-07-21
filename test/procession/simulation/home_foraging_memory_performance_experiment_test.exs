defmodule Procession.Simulation.HomeForagingMemoryPerformanceExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.HomeForagingMemoryPerformanceExperiment, as: Experiment

  test "runs matched behavioral cohorts and reports withdrawal outcomes" do
    result = Experiment.run(population: 2, teaching_ticks: 120, withdrawal_ticks: 80, seed: 3)

    assert Map.keys(result.summary) |> Enum.sort() ==
             [:legacy_memory, :memory_ignored, :quality_memory]

    for condition <- [:legacy_memory, :memory_ignored, :quality_memory] do
      summary = result.summary[condition]
      assert summary.cycles >= 0.0
      assert summary.correct >= 0.0 and summary.correct <= 1.0
      assert summary.move_rate >= 0.0 and summary.move_rate <= 1.0
      assert summary.recovery >= 0.0 and summary.recovery <= 1.0
    end
  end
end
