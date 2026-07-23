defmodule Procession.Simulation.HomeForagingPressureControlExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.HomeForagingPressureControlExperiment

  test "runs pressure profiles and the matched no-teacher control" do
    result = HomeForagingPressureControlExperiment.run(
      population: 2,
      seed: 7,
      stage_ticks: 3,
      withdrawal_ticks: 5
    )

    assert Map.has_key?(result.summary, {:ultra_forgiving, :abrupt_assistance})
    assert Map.has_key?(result.summary, {:moderate_pressure, :staged_assistance})
    assert Map.has_key?(result.summary, {:slow_pressure, :staged_assistance})
    assert Map.has_key?(result.summary, {:full_pressure, :abrupt_assistance})
    assert Map.has_key?(result.summary, {:ultra_forgiving, :no_teacher})
    assert length(result.rows) == 18
  end
end
