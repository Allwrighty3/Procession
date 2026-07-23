defmodule Procession.Simulation.HomeForagingUngroundedControlExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.HomeForagingUngroundedControlExperiment

  test "runs opaque-motor no-teacher learners" do
    result = HomeForagingUngroundedControlExperiment.run(population: 2, seed: 7, ticks: 40)

    assert result.population == 2
    assert length(result.rows) == 2
    assert Enum.all?(result.rows, &is_number(&1.impulse_entropy))
    assert result.summary.survived <= 2
  end
end
