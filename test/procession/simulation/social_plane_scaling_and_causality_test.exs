defmodule Procession.Simulation.SocialPlaneScalingAndCausalityTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalSensorimotorField
  alias Procession.Simulation.SocialRelationPlane

  @field_opts [
    micro_nodes: 128,
    input_width: 5,
    encoding_salt: :social_motor_causality,
    dynamic_salience: true,
    output_source_threshold: 0.0,
    output_plasticity_fanout: 16,
    output_plasticity_budget: 0.20
  ]

  defp event do
    %{
      tick: 1,
      entity_id: "actor",
      motor_pattern: {:m1, :m2},
      from: {1, 1},
      proposed: {2, 1},
      position: {2, 1},
      displaced?: true,
      blocked?: false,
      transferred: 0.0
    }
  end

  test "social exposure remains bounded under long repetition" do
    plane =
      Enum.reduce(1..1_000, SocialRelationPlane.new(), fn tick, acc ->
        {updated, _signals} =
          SocialRelationPlane.observe(
            acc,
            "observer",
            event(),
            tick,
            social_exposure_ceiling: 25.0
          )

        updated
      end)

    relation =
      SocialRelationPlane.relation(plane, "observer", "actor", {:movement_attempt, :east})

    assert relation.exposure == 25.0
    assert relation.confidence <= 1.0
    assert relation.persistence <= 4.0
  end

  test "the same event creates different social persistence after different salience histories" do
    feature = SocialRelationPlane.physical_observation_feature(event())
    signal = {:signal, feature, 3.0}

    fresh_field =
      DevelopmentalSensorimotorField.new(@field_opts)
      |> DevelopmentalSensorimotorField.sense([signal], @field_opts)

    habituated_field =
      Enum.reduce(1..20, DevelopmentalSensorimotorField.new(@field_opts), fn _, field ->
        DevelopmentalSensorimotorField.sense(field, [signal], @field_opts)
      end)

    fresh_salience =
      fresh_field
      |> DevelopmentalSensorimotorField.salience_metrics()
      |> get_in([:effective_signals, feature])

    habituated_salience =
      habituated_field
      |> DevelopmentalSensorimotorField.salience_metrics()
      |> get_in([:effective_signals, feature])

    assert fresh_salience > habituated_salience

    {fresh_plane, _} =
      SocialRelationPlane.observe(
        SocialRelationPlane.new(),
        "fresh_observer",
        event(),
        1,
        observer_salience: fresh_salience
      )

    {habituated_plane, _} =
      SocialRelationPlane.observe(
        SocialRelationPlane.new(),
        "habituated_observer",
        event(),
        1,
        observer_salience: habituated_salience
      )

    context = {:movement_attempt, :east}
    fresh = SocialRelationPlane.relation(fresh_plane, "fresh_observer", "actor", context)

    habituated =
      SocialRelationPlane.relation(habituated_plane, "habituated_observer", "actor", context)

    assert fresh.persistence > habituated.persistence
  end

  test "social-plane signals become learned support for later opaque motor output" do
    {plane, signals} = SocialRelationPlane.observe(SocialRelationPlane.new(), "observer", event(), 1)
    assert plane.observations == 1

    output = {:m2, :m6}

    social_field =
      Enum.reduce(1..10, DevelopmentalSensorimotorField.new(@field_opts), fn _, field ->
        field
        |> DevelopmentalSensorimotorField.sense(signals, @field_opts)
        |> DevelopmentalSensorimotorField.record_output(output, 1.0, @field_opts)
      end)

    control_field =
      Enum.reduce(1..10, DevelopmentalSensorimotorField.new(@field_opts), fn _, field ->
        field
        |> DevelopmentalSensorimotorField.sense([{:signal, :unrelated_background, 1.0}], @field_opts)
        |> DevelopmentalSensorimotorField.record_output(output, 1.0, @field_opts)
      end)

    social_probe = DevelopmentalSensorimotorField.sense(social_field, signals, @field_opts)
    control_probe = DevelopmentalSensorimotorField.sense(control_field, signals, @field_opts)

    social_score =
      DevelopmentalSensorimotorField.output_score(social_probe, output, @field_opts)

    control_score =
      DevelopmentalSensorimotorField.output_score(control_probe, output, @field_opts)

    assert social_score > 0.0
    assert social_score > control_score
  end
end