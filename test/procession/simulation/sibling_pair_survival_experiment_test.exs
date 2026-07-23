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
    assert result.signal_pathway_rule == :experienced_teacher_signal_and_generated_motor_binding

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
      assert row.emitted_signals <= row.signal_attempts
    end)
  end

  test "teacher signals in every teacher condition regardless of peer signaling" do
    result =
      Experiment.run(
        population: 2,
        baby_ticks: 40,
        participation_ticks: 40,
        withdrawal_ticks: 20,
        seed: 11,
        intent_timeout_ms: 20
      )

    assert result.summary.teacher_sibling_invisible.teacher_signals > 0
    assert result.summary.teacher_sibling_visible.teacher_signals > 0
    assert result.summary.teacher_sibling_signals.teacher_signals > 0
    assert result.summary.no_teacher_sibling_visible.teacher_signals == 0
    assert result.summary.no_teacher_sibling_signals.teacher_signals == 0
  end

  test "peer signal emission requires signal mode, teacher experience, and a generated pathway" do
    result =
      Experiment.run(
        population: 2,
        baby_ticks: 20,
        participation_ticks: 20,
        withdrawal_ticks: 80,
        seed: 17,
        intent_timeout_ms: 20
      )

    invisible = result.summary.teacher_sibling_invisible
    visible = result.summary.teacher_sibling_visible
    signaled = result.summary.teacher_sibling_signals
    orphan_signaled = result.summary.no_teacher_sibling_signals

    assert invisible.follow_rate == 0.0
    assert invisible.emitted_signals == 0
    assert visible.emitted_signals == 0
    assert signaled.emitted_signals <= signaled.signal_attempts
    assert orphan_signaled.emitted_signals == 0

    report = Experiment.report(result)
    refute report =~ "teacher_alone"
    refute report =~ "no_teacher_alone"
    assert report =~ "same pre-tick world snapshot"
    assert report =~ "teacher experience and a generated signal/motor binding"
  end
end
