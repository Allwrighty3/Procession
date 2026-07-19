defmodule Procession.Simulation.DevelopmentalOriginExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalOriginExperiment

  test "reports history and rule comparisons without outcome scoring" do
    result = DevelopmentalOriginExperiment.run(ticks: 240, seed: 7)

    assert Map.keys(result.history_runs) |> Enum.sort() == [:actual, :cooccurrence_shuffled, :outcome_decoupled, :time_shuffled]
    assert Map.keys(result.rule_runs) |> Enum.sort() == [:base, :faster_decay, :looser, :stricter]
    assert result.history_similarity.actual.support_similarity == 1.0
    assert result.rule_similarity.base.edge_similarity == 1.0

    report = DevelopmentalOriginExperiment.report(result)
    assert report =~ "History variants"
    assert report =~ "Rule variants"
    assert report =~ "outcome quality is intentionally not scored"
  end

  test "generated nodes retain pre-consolidation evidence" do
    result = DevelopmentalOriginExperiment.run(ticks: 240, seed: 3)

    for node <- result.history_runs.actual.nodes do
      assert is_integer(node.formed_tick)
      assert node.formed_tick > 0
      assert node.formation_coherence >= 0.0
    end
  end
end
