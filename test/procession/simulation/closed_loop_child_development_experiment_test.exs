defmodule Procession.Simulation.ClosedLoopChildDevelopmentExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ClosedLoopChildDevelopmentExperiment

  test "clone controls remain structurally identical" do
    result = ClosedLoopChildDevelopmentExperiment.run(population: 2, phase_ticks: 72, seed: 9)

    assert result.clone_control.support_similarity == 1.0
    assert result.clone_control.edge_similarity == 1.0
    assert result.clone_control.profile_similarity == 1.0
  end

  test "all caregiver policies produce observable closed-loop populations" do
    result = ClosedLoopChildDevelopmentExperiment.run(population: 2, phase_ticks: 72, seed: 4)

    Enum.each([:responsive, :inconsistent, :aversive, :absent], fn policy ->
      summary = Map.fetch!(result.conditions, policy)

      assert summary.phase_one_generated >= 0.0
      assert summary.phase_two_generated >= summary.phase_one_generated
      assert summary.phase_two_arousal >= 0.0
      assert summary.phase_two_arousal <= 1.0
      assert summary.phase_two_signal_rate >= 0.0
      assert summary.phase_two_signal_rate <= 1.0
      assert summary.support_similarity >= 0.0
      assert summary.support_similarity <= 1.0
    end)
  end

  test "report does not assign psychological labels" do
    report =
      [population: 2, phase_ticks: 48, seed: 2]
      |> ClosedLoopChildDevelopmentExperiment.run()
      |> ClosedLoopChildDevelopmentExperiment.report()

    assert report =~ "Closed-loop child development"
    assert report =~ "responsive:"
    refute report =~ "attachment style"
    refute report =~ "secure"
    refute report =~ "anxious"
  end
end