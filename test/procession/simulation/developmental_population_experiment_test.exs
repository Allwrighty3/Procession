defmodule Procession.Simulation.DevelopmentalPopulationExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalPopulationExperiment

  test "cloned entities remain identical while varied populations remain observable" do
    result = DevelopmentalPopulationExperiment.run(population: 3, ticks: 192, seed: 7)

    assert result.clones.node_min == result.clones.node_max
    assert result.clones.support_similarity == 1.0
    assert result.clones.edge_similarity == 1.0
    assert result.clones.profile_similarity == 1.0

    Enum.each([result.salted, result.varied_history, result.salted_varied], fn group ->
      assert group.node_min >= 0
      assert group.node_max >= group.node_min
      assert group.eligible_coverage_mean >= 0.0
      assert group.distinct_coverage_mean >= 0.0
      assert group.profile_similarity >= 0.0
      assert group.profile_similarity <= 1.0
    end)
  end

  test "report separates individuality from consolidation coverage" do
    result = DevelopmentalPopulationExperiment.run(population: 2, ticks: 96, seed: 3)
    report = DevelopmentalPopulationExperiment.report(result)

    assert report =~ "Developmental population divergence"
    assert report =~ "eligible_coverage="
    assert report =~ "distinct_coverage="
    assert report =~ "salted_varied:"
  end
end