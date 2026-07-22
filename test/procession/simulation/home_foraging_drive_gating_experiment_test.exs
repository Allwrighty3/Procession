defmodule Procession.Simulation.HomeForagingDriveGatingExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.HomeForagingDriveGatingExperiment

  test "reports continuous metrics for all drive conditions" do
    result = HomeForagingDriveGatingExperiment.run(
      population: 2,
      teaching_ticks: 80,
      withdrawal_ticks: 120,
      seed: 3
    )

    assert Map.keys(result.summary) |> Enum.sort() ==
             [:context_gated, :direct_drive, :stagnation_recovery]

    Enum.each(result.summary, fn {_condition, metrics} ->
      assert metrics.mean_hunger >= 0.0
      assert metrics.saturation >= 0.0 and metrics.saturation <= 1.0
      assert metrics.dominance >= 0.0 and metrics.dominance <= 1.0
      assert metrics.entropy >= 0.0
      assert metrics.repeat_run >= 1.0
      assert metrics.eligible >= 0.0 and metrics.eligible <= 1.0
      assert metrics.transition_rate >= 0.0 and metrics.transition_rate <= 1.0
      assert metrics.progress_rate >= 0.0 and metrics.progress_rate <= 1.0
    end)
  end
end