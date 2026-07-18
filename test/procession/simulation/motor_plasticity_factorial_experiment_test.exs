defmodule Procession.Simulation.MotorPlasticityFactorialExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.MotorPlasticityFactorialExperiment, as: Experiment

  test "comparison covers every motor and plasticity combination" do
    results = Experiment.compare(ticks: 40, reversal_tick: 20, seeds: Enum.to_list(1..4))

    for motor <- Experiment.motor_modes(), profile <- Experiment.profiles() do
      assert Map.has_key?(results, {motor, profile})
    end
  end

  test "factorial comparison is deterministic for a fixed seed set" do
    opts = [ticks: 60, reversal_tick: 30, seeds: Enum.to_list(1..10)]
    assert Experiment.compare(opts) == Experiment.compare(opts)
  end

  test "active-direction switching spans intervening remains" do
    states =
      for motor <- Experiment.motor_modes(), profile <- Experiment.profiles(), seed <- 1..20 do
        Experiment.run(motor_mode: motor, profile: profile, seed: seed,
          ticks: 100, reversal_tick: 50)
      end

    assert Enum.any?(states, &(&1.switches > 0))
  end
end
