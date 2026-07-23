defmodule Procession.Simulation.SiblingSignalFollowupExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.SiblingSignalFollowupExperiment, as: Experiment

  test "runs equal-blind sibling conditions through supervised OTP learners" do
    result = Experiment.run(population: 2, teaching_ticks: 20, transfer_ticks: 40, seed: 5)

    assert result.execution_model == :supervised_otp_concurrent_decision
    assert result.learning_scale == 0.01
    assert Map.keys(result.summary) |> Enum.sort() == [:isolated, :signals, :visible]
    assert length(result.rows) == 6

    Enum.each(result.rows, fn row ->
      assert row.learner_a.id == :a
      assert row.learner_b.id == :b
      assert row.learner_a.decisions == 40
      assert row.learner_b.decisions == 40
    end)
  end

  test "independent exploration causes sibling action divergence" do
    result = Experiment.run(population: 2, teaching_ticks: 20, transfer_ticks: 120, seed: 11)

    assert result.summary.isolated.action_divergence > 0.0
    assert result.summary.visible.action_divergence > 0.0
    assert result.summary.signals.signal_attempts > 0
    assert Experiment.report(result) =~ "equal-blind"
  end
end
