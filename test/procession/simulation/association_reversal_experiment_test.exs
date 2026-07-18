defmodule Procession.Simulation.AssociationReversalExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.AssociationReversalExperiment, as: Experiment

  test "comparison reports both learning variants" do
    results = Experiment.compare(ticks: 60, reversal_tick: 30, seeds: Enum.to_list(1..4))

    assert Map.has_key?(results, :outcome_adaptive)
    assert Map.has_key?(results, :local_adaptive)
  end

  test "entities can form mistaken attributions" do
    states =
      Enum.map(1..20, fn seed ->
        Experiment.run(seed: seed, ticks: 100, reversal_tick: 50,
          variant: :outcome_adaptive, coincidence_rate: 0.35)
      end)

    assert Enum.any?(states, &(&1.mistaken_attributions > 0))
  end

  test "reversal can leave obsolete behavior after the world changes" do
    states =
      Enum.map(1..20, fn seed ->
        Experiment.run(seed: seed, ticks: 120, reversal_tick: 60,
          variant: :local_adaptive)
      end)

    assert Enum.any?(states, &(&1.obsolete_actions > 0))
  end

  test "the entity state has no correct-action or reversal flag" do
    state = Experiment.run(ticks: 1)

    refute Map.has_key?(state, :correct_action)
    refute Map.has_key?(state, :reversal_tick)
    refute Map.has_key?(state, :cause_graph)
  end
end
