defmodule Procession.Simulation.PrimitiveDevelopmentExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.PrimitiveDevelopmentExperiment, as: Experiment

  test "exposes only low-level body controls" do
    controls = Experiment.controls()

    assert controls == [
             :translate_x_positive,
             :translate_x_negative,
             :translate_y_positive,
             :translate_y_negative,
             :extend_limb,
             :contract_limb,
             :phonate_low,
             :phonate_high,
             :relax
           ]

    refute :reach in controls
    refute :manipulate in controls
    refute :feed in controls
    refute :follow in controls
    refute :signal in controls
  end

  test "runs paired primitive bodies through world-owned deadlines" do
    result =
      Experiment.run(
        population: 1,
        baby_ticks: 20,
        participation_ticks: 20,
        withdrawal_ticks: 40,
        seed: 5,
        intent_timeout_ms: 20
      )

    assert result.execution_model == :simultaneous_primitive_body_deadlines
    assert result.action_level == :body_control_primitives

    assert Map.keys(result.summary) |> Enum.sort() ==
             [
               :orphan_pair_audible,
               :orphan_pair_visible,
               :teacher_pair_audible,
               :teacher_pair_invisible,
               :teacher_pair_visible
             ]

    assert length(result.rows) == 5

    Enum.each(result.rows, fn row ->
      assert row.learner_count == 2
      assert row.accepted_intents + row.missed_intents == 160
      assert row.baby_survived <= 2
      assert row.participation_survived <= 2
      assert row.withdrawal_survived <= 2
      assert row.learned_ticks == 160
      assert row.episode_count <= 24
      assert row.plasticity_total > 0.0
      assert row.surprise_total > 0.0
    end)
  end

  test "observer diagnostics do not become learner action names" do
    result =
      Experiment.run(
        population: 1,
        baby_ticks: 30,
        participation_ticks: 30,
        withdrawal_ticks: 60,
        seed: 11,
        intent_timeout_ms: 20
      )

    report = Experiment.report(result)

    assert report =~ "named behaviors are observer diagnostics"
    assert report =~ "contacts="
    assert report =~ "feed_sequences="
    assert report =~ "phonations="
    assert report =~ "plasticity="
    assert report =~ "surprise="
  end
end
