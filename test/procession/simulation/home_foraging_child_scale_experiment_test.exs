defmodule Procession.Simulation.HomeForagingChildScaleExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.ChildDevelopmentSchedule
  alias Procession.Simulation.HomeForagingChildScaleExperiment, as: Experiment

  test "schedule represents five developmental years and two unsupported years" do
    assert ChildDevelopmentSchedule.teaching_ticks() == 29_200
    assert ChildDevelopmentSchedule.total_ticks() == 40_880
    assert Enum.map(ChildDevelopmentSchedule.phases(), & &1.name) ==
             [:infancy, :toddlerhood, :early_childhood, :unsupported_transfer]
  end

  test "scaled run preserves paired taught and no-teacher cohorts" do
    result = Experiment.run(population: 3, seed: 11, phase_scale: 0.002)

    assert length(result.rows) == 6
    assert Map.has_key?(result.summary, :no_teacher)
    assert Map.has_key?(result.summary, :taught)
    assert result.teaching_ticks < result.total_ticks
  end
end
