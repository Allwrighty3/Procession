defmodule Procession.Simulation.SiblingSignalFollowupExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.SiblingSignalFollowupExperiment, as: Experiment

  test "runs restored teacher and survival factorial through world-owned ticks" do
    result =
      Experiment.run(
        population: 1,
        baby_ticks: 20,
        participation_ticks: 20,
        withdrawal_ticks: 40,
        seed: 5,
        intent_timeout_ms: 20
      )

    assert result.execution_model == :world_owned_deadline_ticks
    assert result.learning_scale == 0.01

    assert Map.keys(result.summary) |> Enum.sort() ==
             [
               :no_teacher_alone,
               :no_teacher_sibling_signals,
               :no_teacher_sibling_visible,
               :teacher_alone,
               :teacher_sibling_invisible,
               :teacher_sibling_signals,
               :teacher_sibling_visible
             ]

    assert length(result.rows) == 7

    Enum.each(result.rows, fn row ->
      expected = row.learner_count * 80
      assert row.accepted_intents + row.missed_intents == expected
      assert row.baby_survived <= row.learner_count
      assert row.participation_survived <= row.learner_count
      assert row.withdrawal_survived <= row.learner_count
    end)
  end

  test "teacher and sibling factors remain separately measurable" do
    result =
      Experiment.run(
        population: 1,
        baby_ticks: 30,
        participation_ticks: 30,
        withdrawal_ticks: 60,
        seed: 11,
        intent_timeout_ms: 20
      )

    assert result.summary.teacher_alone.mean_caregiver_intake > 0.0
    assert result.summary.no_teacher_alone.mean_caregiver_intake == 0.0
    assert result.summary.teacher_sibling_signals.signal_attempts > 0
    assert result.summary.no_teacher_sibling_signals.signal_attempts > 0

    report = Experiment.report(result)
    assert report =~ "restored baseline physics and teacher"
    assert report =~ "teacher_sibling_visible"
    assert report =~ "missed="
  end
end
