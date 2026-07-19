defmodule Procession.Simulation.RefractoryPlasticityExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RefractoryPlasticityExperiment, as: Experiment

  test "comparison covers current, moderate, and flexible plasticity profiles" do
    results = Experiment.compare(ticks: 40, reversal_tick: 20, seeds: Enum.to_list(1..4))

    assert Map.has_key?(results, :current)
    assert Map.has_key?(results, :moderate)
    assert Map.has_key?(results, :flexible)
  end

  test "refractory state emerges from sustained motor output" do
    states =
      Enum.map(1..20, fn seed ->
        Experiment.run(
          profile: :moderate,
          ticks: 100,
          reversal_tick: 50,
          seed: seed,
          refractory_gain: 0.30,
          refractory_recovery: 0.50
        )
      end)

    assert Enum.any?(states, fn state ->
             state.refractory.left > 0.0 or state.refractory.right > 0.0
           end)

    assert Enum.any?(states, fn state ->
             state.action_counts.left + state.action_counts.right > 0
           end)
  end

  test "plasticity profiles remain deterministic for a fixed seed set" do
    opts = [ticks: 60, reversal_tick: 30, seeds: Enum.to_list(1..10)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end
end
