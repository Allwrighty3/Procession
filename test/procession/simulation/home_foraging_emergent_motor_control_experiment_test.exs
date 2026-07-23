defmodule Procession.Simulation.HomeForagingEmergentMotorControlExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.HomeForagingEmergentMotorControlExperiment, as: Experiment

  test "matched taught cohort develops more motor competence than no-teacher control" do
    result =
      Experiment.run(
        population: 8,
        seed: 11,
        max_ticks: 160,
        teaching_ticks: 120
      )

    control = result.summary.no_teacher
    taught = result.summary.taught

    assert length(result.rows) == 16
    assert control.survived == 0
    assert control.consumed == 0
    assert control.collected == 0
    assert control.median_death_tick < 160
    assert control.stable_patterns < 1.0

    assert taught.stable_patterns > control.stable_patterns
    assert taught.strongest_coordination > control.strongest_coordination
    assert taught.displacement_rate > control.displacement_rate
    assert taught.reached_food > control.reached_food
    assert taught.assistance_rate > 0.0
    assert control.assistance_rate == 0.0
  end

  test "report exposes both matched cohorts and autonomous withdrawal" do
    report =
      Experiment.run(population: 2, seed: 5, max_ticks: 80, teaching_ticks: 60)
      |> Experiment.report()

    assert report =~ "Emergent-movement taught comparison"
    assert report =~ "no_teacher:"
    assert report =~ "taught:"
    assert report =~ "survived_withdrawal"
    assert report =~ "learner emits every motor pattern"
  end
end