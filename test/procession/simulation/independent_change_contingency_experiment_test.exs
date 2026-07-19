defmodule Procession.Simulation.IndependentChangeContingencyExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.IndependentChangeContingencyExperiment, as: Experiment

  test "comparison covers environmental, motor, and learning controls" do
    results = Experiment.compare(ticks: 40, seeds: Enum.to_list(1..4))

    assert Map.has_key?(results, {:stable, :reliable, :reactive})
    assert Map.has_key?(results, {:independent_changes, :noisy, :outcome_adaptive})
    assert Map.has_key?(results, {:independent_changes, :noisy, :local_adaptive})
  end

  test "local learning may misattribute independently produced improvement" do
    states =
      Enum.map(1..40, fn seed ->
        Experiment.run(
          variant: :local_adaptive,
          motor_mode: :noisy,
          environment_mode: :independent_changes,
          ticks: 140,
          seed: seed,
          effect_delay: 2,
          ambient_interval: 2,
          ambient_amplitude: 0.09
        )
      end)

    assert Enum.any?(states, &(&1.misattributions > 0))
    assert Enum.all?(states, &(&1.attributions == &1.accurate_attributions + &1.misattributions))
  end

  test "stable reliable conditions support more accurate than mistaken attributions" do
    states =
      Enum.map(1..20, fn seed ->
        Experiment.run(
          variant: :local_adaptive,
          motor_mode: :reliable,
          environment_mode: :stable,
          ticks: 120,
          seed: seed
        )
      end)

    accurate = Enum.sum(Enum.map(states, & &1.accurate_attributions))
    mistaken = Enum.sum(Enum.map(states, & &1.misattributions))
    assert accurate > mistaken
  end

  test "100-sample summaries expose survival and attribution metrics" do
    results = Experiment.compare(ticks: 20, seeds: Enum.to_list(1..100))
    summary = Map.fetch!(results, {:independent_changes, :noisy, :local_adaptive})

    assert summary.samples == 100
    assert summary.survived in 0..100
    assert summary.survival_rate >= 0.0 and summary.survival_rate <= 1.0
    assert summary.misattribution_rate >= 0.0 and summary.misattribution_rate <= 1.0
  end

  test "world state still has no causal provenance interface" do
    state = Experiment.run(ticks: 1)

    refute Map.has_key?(state, :cause_graph)
    refute Map.has_key?(state, :world_provenance)
    assert is_map(state.traces)
  end
end
