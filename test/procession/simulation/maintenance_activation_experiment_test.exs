defmodule Procession.Simulation.MaintenanceActivationExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.MaintenanceActivationExperiment, as: Experiment

  test "uncoupled maintenance strain cannot alter environmental position" do
    state = Experiment.run(variant: :uncoupled, ticks: 80, seed: 7)

    assert state.position == 6
    assert state.approaches == 0
    assert state.remains == state.tick
    refute state.persisted
  end

  test "reactive coupling can turn internal strain into world-facing action" do
    state = Experiment.run(variant: :reactive, ticks: 80, seed: 7)

    assert state.approaches > 0
    assert state.position < 6
    assert Enum.any?(state.history, &(&1.action == :approach))
  end

  test "adaptive coupling changes future propagation after improved access" do
    state = Experiment.run(variant: :adaptive, ticks: 80, seed: 7)

    approach_resistance = CognitiveField.resistance(state.field, :strain, :approach)
    remain_resistance = CognitiveField.resistance(state.field, :strain, :remain)

    assert Enum.any?(state.history, & &1.improved_access)
    assert approach_resistance < remain_resistance
  end

  test "coupled populations persist longer than the uncoupled control" do
    comparison = Experiment.compare(ticks: 100, seeds: Enum.to_list(1..40))

    uncoupled = comparison.summaries.uncoupled
    reactive = comparison.summaries.reactive
    adaptive = comparison.summaries.adaptive

    assert reactive.median_lifetime > uncoupled.median_lifetime
    assert adaptive.median_lifetime > uncoupled.median_lifetime
    assert reactive.survived > uncoupled.survived
    assert adaptive.survived > uncoupled.survived
  end

  test "reports distributions and declares absent prerequisite systems" do
    comparison = Experiment.compare(ticks: 40, seeds: Enum.to_list(1..8))
    report = Experiment.report(comparison)

    assert report =~ "uncoupled: median="
    assert report =~ "reactive: median="
    assert report =~ "adaptive: median="
    assert :real_physiology in Experiment.missing_couplings()
    assert :other_entities in Experiment.missing_couplings()
    assert :semantic_cognition in Experiment.missing_couplings()
  end
end
