defmodule Procession.Simulation.SiblingPairSurvivalExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.SiblingPairSurvivalExperiment, as: Experiment

  test "runs only sibling conditions from simultaneous world snapshots" do
    result =
      Experiment.run(
        population: 2,
        baby_ticks: 20,
        participation_ticks: 20,
        withdrawal_ticks: 40,
        seed: 5,
        intent_timeout_ms: 20
      )

    assert result.execution_model == :simultaneous_world_snapshot_deadlines
    assert result.learning_scale == 0.01

    assert Map.keys(result.summary) |> Enum.sort() ==
             [
               :no_teacher_sibling_signals,
               :no_teacher_sibling_visible,
               :teacher_sibling_invisible,
               :teacher_sibling_signals,
               :teacher_sibling_visible
             ]

    assert length(result.rows) == 10

    Enum.each(result.rows, fn row ->
      assert row.learner_count == 2
      assert row.accepted_intents + row.missed_intents == 160
    end)
  end

  test "invisible condition exposes no follow opportunities or signal actions" do
    result =
      Experiment.run(
        population: 2,
        baby_ticks: 20,
        participation_ticks: 20,
        withdrawal_ticks: 80,
        seed: 11,
        intent_timeout_ms: 20
      )

    invisible = result.summary.teacher_sibling_invisible
    assert invisible.follow_rate == 0.0
    assert invisible.signal_attempts == 0

    report = Experiment.report(result)
    refute report =~ "teacher_alone"
    refute report =~ "no_teacher_alone"
    assert report =~ "same pre-tick world snapshot"
  end
end
