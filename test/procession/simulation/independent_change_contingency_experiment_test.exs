defmodule Procession.Simulation.IndependentChangeContingencyExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.IndependentChangeContingencyExperiment, as: Experiment

  test "comparison covers environmental, motor, and learning controls" do
    results = Experiment.compare(ticks: 40, seeds: Enum.to_list(1..4))

    assert Map.has_key?(results, {:stable, :reliable, :reactive})
    assert Map.has_key?(results, {:independent_changes, :noisy, :outcome_adaptive})
    assert Map.has_key?(results, {:independent_changes, :noisy, :contingency_adaptive})
  end

  test "contingency learning requires an immediate local consequence" do
    state =
      Experiment.run(
        variant: :contingency_adaptive,
        motor_mode: :reliable,
        environment_mode: :independent_changes,
        ticks: 100,
        seed: 7,
        effect_delay: 2
      )

    assert state.confirmed_contingencies > 0
    assert state.false_credit == 0
  end

  test "outcome-only learning can credit independent improvement" do
    states =
      Enum.map(1..20, fn seed ->
        Experiment.run(
          variant: :outcome_adaptive,
          motor_mode: :noisy,
          environment_mode: :independent_changes,
          ticks: 120,
          seed: seed,
          effect_delay: 2
        )
      end)

    assert Enum.any?(states, &(&1.false_credit > 0))
  end

  test "world state still has no causal provenance interface" do
    state = Experiment.run(ticks: 1)

    refute Map.has_key?(state, :cause_graph)
    refute Map.has_key?(state, :world_provenance)
    assert is_map(state.traces)
  end
end
