defmodule Procession.Simulation.ClosedLoopPrimitiveExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.ClosedLoopPrimitiveExperiment, as: Experiment
  alias Procession.Simulation.DevelopmentalField
  alias Procession.Simulation.MentalPlaneMotorReadout
  alias Procession.Simulation.PrimitiveActionDynamics

  test "exposes only low-level body controls with physical durations" do
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

    assert Enum.all?(Experiment.action_durations(), fn {_control, duration} -> duration > 1 end)
    refute :reach in controls
    refute :manipulate in controls
    refute :feed in controls
    refute :follow in controls
    refute :signal in controls
  end

  test "body action progresses over several ticks before completing" do
    action = PrimitiveActionDynamics.start(:extend_limb)
    assert action.elapsed == 0
    refute PrimitiveActionDynamics.completing?(action)

    {:continuing, action} = PrimitiveActionDynamics.advance(action)
    {:continuing, action} = PrimitiveActionDynamics.advance(action)
    {:continuing, action} = PrimitiveActionDynamics.advance(action)
    assert PrimitiveActionDynamics.completing?(action)
    assert {:completed, %{elapsed: 4}} = PrimitiveActionDynamics.advance(action)
  end

  test "learned field edges directly increase a motor population drive" do
    opts = [
      micro_nodes: 128,
      input_width: 3,
      encoding_salt: :motor_readout_test,
      consolidation_threshold: 4,
      coherence_threshold: 0.01,
      minimum_compression_gain: -100.0,
      plasticity_budget: 0.20,
      activity_retention: 0.75,
      edge_retention: 1.0,
      propagation_gain: 1.5
    ]

    field = DevelopmentalField.new(opts)

    trained =
      Enum.reduce(1..80, field, fn _iteration, acc ->
        acc
        |> DevelopmentalField.step(
          {:features, [{:body_hunger, :high}, {:local_signature, :rough_cool}]},
          opts
        )
        |> DevelopmentalField.step({:features, [{:motor_channel, :extend_limb}]}, opts)
      end)

    primed =
      DevelopmentalField.step(
        trained,
        {:features, [{:body_hunger, :high}, {:local_signature, :rough_cool}]},
        Keyword.put(opts, :plasticity_budget, 0.0)
      )

    drives = MentalPlaneMotorReadout.drives(primed, [:extend_limb, :phonate_high], opts)
    assert drives.extend_limb > drives.phonate_high
  end

  test "runs paired bodies through a temporally extended mental-plane loop" do
    result =
      Experiment.run(
        population: 1,
        baby_ticks: 20,
        participation_ticks: 20,
        withdrawal_ticks: 40,
        seed: 5,
        intent_timeout_ms: 20
      )

    assert result.execution_model == :mental_plane_closed_sensorimotor_loop
    assert result.action_level == :temporally_extended_body_control_primitives
    assert result.controller == :developmental_field_motor_populations

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
      assert row.action_starts < row.ticks
      assert row.action_completions <= row.action_starts
      assert row.busy_ticks > 0
      assert row.field_driven_starts + row.spontaneous_starts == row.action_starts
      assert row.generated_nodes >= 0
    end)
  end

  test "report states that motor processes take multiple ticks" do
    result =
      Experiment.run(
        population: 1,
        baby_ticks: 20,
        participation_ticks: 20,
        withdrawal_ticks: 40,
        seed: 11,
        intent_timeout_ms: 20
      )

    report = Experiment.report(result)
    assert report =~ "bodies advance them over multiple ticks"
    assert report =~ "no learner action values, prediction maps, episode memory"
    assert report =~ "starts="
    assert report =~ "completions="
    assert report =~ "busy_ticks="
  end
end
