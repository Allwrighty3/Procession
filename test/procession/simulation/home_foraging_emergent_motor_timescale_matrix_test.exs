defmodule Procession.Simulation.HomeForagingEmergentMotorTimescaleMatrixTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.HomeForagingEmergentMotorTimescaleMatrix, as: Matrix

  test "runs all profiles with matched taught and no-teacher cohorts" do
    result = Matrix.run(population: 2, seed: 9)

    assert Matrix.profiles() == [
             :short_full_pressure,
             :ultra_slow_forgiving,
             :ultra_slow_moderate
           ]

    for profile <- Matrix.profiles() do
      experiment = Map.fetch!(result.results, profile)
      assert length(experiment.rows) == 4
      assert Map.has_key?(experiment.summary, :no_teacher)
      assert Map.has_key?(experiment.summary, :taught)
    end
  end

  test "report keeps short and ultra-slow comparisons visible" do
    report = Matrix.run(population: 1, seed: 3) |> Matrix.report()

    assert report =~ "short_full_pressure/no_teacher"
    assert report =~ "ultra_slow_forgiving/taught"
    assert report =~ "ultra_slow_moderate/taught"
  end
end
