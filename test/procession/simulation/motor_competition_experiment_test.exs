defmodule Procession.Simulation.MotorCompetitionExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.MotorCompetitionExperiment, as: Experiment

  test "comparison includes weighted and competing motor controls" do
    results = Experiment.compare(ticks: 40, reversal_tick: 20, seeds: Enum.to_list(1..4))

    assert Map.has_key?(results, :weighted_choice)
    assert Map.has_key?(results, :motor_competition)
    assert Map.has_key?(results, :fluctuating_competition)
    assert Map.has_key?(results, :embodied_competition)
    assert Map.has_key?(results, :redistributed_competition)
  end

  test "remain emerges when competing motor pressure does not overcome threshold" do
    state =
      Experiment.run(
        mode: :motor_competition,
        ticks: 10,
        reversal_tick: 5,
        seed: 3,
        motor_threshold: 10.0
      )

    assert state.action_counts.remain == 10
    assert state.action_counts.left == 0
    assert state.action_counts.right == 0
  end

  test "competing channels retain simultaneous activation" do
    state =
      Experiment.run(
        mode: :motor_competition,
        ticks: 2,
        reversal_tick: 2,
        seed: 5
      )

    assert state.motor.left > 0.0
    assert state.motor.right > 0.0
    assert state.conflict_cost > 0.0
  end

  test "seeded fluctuations can produce population divergence reproducibly" do
    first = Experiment.compare(ticks: 60, reversal_tick: 30, seeds: Enum.to_list(1..10))
    second = Experiment.compare(ticks: 60, reversal_tick: 30, seeds: Enum.to_list(1..10))

    assert first == second
    assert first.fluctuating_competition.median_within_entity_entropy > 0.0
  end

  test "embodied competition accumulates and recovers motor fatigue" do
    state =
      Experiment.run(
        mode: :embodied_competition,
        ticks: 40,
        reversal_tick: 20,
        seed: 7,
        fatigue_gain: 0.12,
        fatigue_recovery: 0.75
      )

    assert state.fatigue_cost > 0.0
    assert state.fatigue.left >= 0.0
    assert state.fatigue.right >= 0.0
  end

  test "failed boundary motion feeds contradiction back to the active route" do
    states =
      Enum.map(1..20, fn seed ->
        Experiment.run(
          mode: :embodied_competition,
          ticks: 80,
          reversal_tick: 40,
          seed: seed,
          world_max: 1,
          initial_position: 0,
          motor_threshold: 0.01
        )
      end)

    assert Enum.any?(states, &(&1.failed_motion_feedback > 0))
  end

  test "motor pressure can transfer into the competing channel" do
    states =
      Enum.map(1..20, fn seed ->
        Experiment.run(
          mode: :redistributed_competition,
          ticks: 100,
          reversal_tick: 50,
          seed: seed,
          world_max: 2,
          initial_position: 0,
          motor_threshold: 0.01,
          fatigue_gain: 0.14,
          redistribution_fraction: 0.60,
          unresolved_redistribution: 0.80
        )
      end)

    assert Enum.any?(states, &(&1.redistributed_activation > 0.0))
    assert Enum.any?(states, &(&1.failed_motion_feedback > 0))
  end
end
