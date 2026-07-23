defmodule Procession.Simulation.HomeForagingRecursiveMemoryIntegrationTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.HomeForagingRecursiveMemoryIntegration, as: Experiment

  test "matched cohorts expose recursive memory structure and output-selection metrics" do
    result = Experiment.run(population: 2, seed: 7, teaching_ticks: 120, withdrawal_ticks: 80)

    assert length(result.rows) == 4
    assert Map.has_key?(result.summary, :memory_disabled)
    assert Map.has_key?(result.summary, :memory_plane)

    for condition <- [:memory_disabled, :memory_plane] do
      summary = result.summary[condition]
      assert summary.generated >= 0.0
      assert summary.recursive >= 0.0
      assert summary.max_depth >= 0.0
      assert summary.withdrawal_correct >= 0.0
      assert summary.withdrawal_correct <= 1.0
    end
  end
end
