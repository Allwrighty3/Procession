defmodule Procession.Simulation.HomeForagingNeedDynamicsExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.HomeForagingNeedDynamicsExperiment

  test "reports graded need and behavior metrics for matched conditions" do
    result = HomeForagingNeedDynamicsExperiment.run(
      population: 2,
      teaching_ticks: 80,
      withdrawal_ticks: 120,
      seed: 3
    )

    assert Map.keys(result.summary) |> Enum.sort() ==
      [:memory_ignored, :need_sensitive_memory, :quality_memory]

    for {_condition, summary} <- result.summary do
      assert is_float(summary.mean_hunger)
      assert is_float(summary.hunger_slope)
      assert is_float(summary.relief)
      assert is_float(summary.relief_duration)
      assert is_float(summary.post_relief_repeat)
      assert is_float(summary.move_rate)
      assert is_float(summary.transition_rate)
      assert is_float(summary.vitality_slope)
      assert is_float(summary.stuck_run)
    end

    report = HomeForagingNeedDynamicsExperiment.report(result)
    assert report =~ "Continuous need-dynamics memory comparison"
    assert report =~ "hunger_slope="
    assert report =~ "vitality_slope="
  end
end
