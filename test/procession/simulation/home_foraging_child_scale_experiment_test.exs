defmodule Procession.Simulation.HomeForagingChildScaleExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.ChildDevelopmentSchedule
  alias Procession.Simulation.HomeForagingChildScaleExperiment, as: Experiment

  test "schedule represents development through age twenty-five" do
    assert ChildDevelopmentSchedule.teaching_ticks() == 70_080
    assert ChildDevelopmentSchedule.care_ticks() == 122_640
    assert ChildDevelopmentSchedule.total_ticks() == 146_000

    assert Enum.map(ChildDevelopmentSchedule.phases(), & &1.name) ==
             [:infancy, :toddlerhood, :early_childhood, :middle_childhood,
              :adolescence, :supported_transition, :independent_adulthood]
  end

  test "scaled run preserves paired taught and no-teacher cohorts" do
    result = Experiment.run(population: 3, seed: 11, phase_scale: 0.0005)

    assert length(result.rows) == 6
    assert Map.has_key?(result.summary, :no_teacher)
    assert Map.has_key?(result.summary, :taught)
    assert result.teaching_ticks < result.care_ticks
    assert result.care_ticks < result.total_ticks
  end
end