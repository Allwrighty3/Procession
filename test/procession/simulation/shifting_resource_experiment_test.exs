defmodule Procession.Simulation.ShiftingResourceExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ShiftingResourceExperiment, as: Experiment

  test "source alternates across the world and is recorded in history" do
    state = Experiment.run(variant: :reactive, ticks: 70, seed: 4, source_interval: 20)
    sources = state.history |> Enum.map(& &1.source) |> Enum.uniq()

    assert 0 in sources
    assert 10 in sources
  end

  test "adaptive consequence sensitivity changes competing route resistance" do
    state = Experiment.run(variant: :adaptive, ticks: 90, seed: 7, source_interval: 20)

    left = Procession.Simulation.CognitiveField.resistance(state.field, :strain, :left)
    right = Procession.Simulation.CognitiveField.resistance(state.field, :strain, :right)

    assert left != right
  end

  test "comparison includes uncoupled reactive maladaptive and adaptive controls" do
    comparison = Experiment.compare(ticks: 90, seeds: Enum.to_list(1..12), source_interval: 20)

    assert Map.keys(comparison.summaries) |> Enum.sort() ==
             [:adaptive, :maladaptive, :reactive, :uncoupled]
  end

  test "adaptive histories record both successful and obsolete movement" do
    state = Experiment.run(variant: :adaptive, ticks: 120, seed: 3, source_interval: 20)

    assert state.successful_adjustments > 0
    assert state.obsolete_actions > 0
    assert state.source_changes_survived > 0
  end

  test "experiment declares important missing couplings" do
    missing = Experiment.missing_couplings()

    assert :real_physiology in missing
    assert :distance_sensing in missing
    assert :other_entities in missing
    assert :semantic_cognition in missing
  end
end
