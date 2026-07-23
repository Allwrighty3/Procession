defmodule Procession.Simulation.SiblingSignalFollowupExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.SiblingSignalFollowupExperiment, as: Experiment

  test "runs equal-blind sibling conditions through world-owned deadline ticks" do
    result =
      Experiment.run(
        population: 2,
        teaching_ticks: 20,
        transfer_ticks: 40,
        seed: 5,
        intent_timeout_ms: 20,
        support_interval: 5
      )

    assert result.execution_model == :world_owned_deadline_ticks
    assert result.learning_scale == 0.01
    assert Map.keys(result.summary) |> Enum.sort() == [:isolated, :signals, :visible]
    assert length(result.rows) == 6

    Enum.each(result.rows, fn row ->
      assert row.learner_a.id == :a
      assert row.learner_b.id == :b
      assert row.learner_a.decisions == 60
      assert row.learner_b.decisions == 60
      assert row.accepted_intents + row.missed_intents == 120
      assert row.support_events == 8
    end)
  end

  test "independent exploration diverges without perfect motor teaching" do
    result =
      Experiment.run(
        population: 2,
        teaching_ticks: 20,
        transfer_ticks: 120,
        seed: 11,
        intent_timeout_ms: 20,
        support_interval: 5
      )

    assert result.summary.isolated.action_divergence > 0.0
    assert result.summary.visible.action_divergence > 0.0
    assert result.summary.signals.signal_attempts > 0
    assert result.summary.isolated.missed_intent_rate >= 0.0

    report = Experiment.report(result)
    assert report =~ "world-owned tick deadlines"
    assert report =~ "no correct actions are inserted"
    assert report =~ "missed="
  end
end
