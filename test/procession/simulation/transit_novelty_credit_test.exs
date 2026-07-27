defmodule Procession.Simulation.TransitNoveltyCreditTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.InTransitDecision

  test "repeated route perception becomes familiar and weakens prior motor support" do
    loop = DevelopmentalSensorimotorLoop.new(seed: 17)

    features = [
      {:signal, {:route_progress, :near_source}, 1.0},
      {:signal, {:route_velocity, :near_zero}, 0.4},
      {:signal, {:far_boundary_distance, :nearby}, 0.5}
    ]

    first = InTransitDecision.experience_metrics(loop, features)
    assert first.change == 1.0
    assert first.familiarity == 0.0
    assert first.repetition == 0.0
    assert first.credit > 0.0

    sensed = DevelopmentalSensorimotorLoop.sense(loop, features)
    repeated = InTransitDecision.experience_metrics(sensed, features)

    assert repeated.change == 0.0
    assert repeated.repetition == 1.0
    assert repeated.familiarity > 0.0
    assert repeated.credit < 0.0
  end

  test "changed route perception gives positive delayed credit without a curiosity flag" do
    loop = DevelopmentalSensorimotorLoop.new(seed: 23)

    prior = [
      {:signal, {:route_progress, :near_source}, 1.0},
      {:signal, {:route_velocity, :near_zero}, 0.4},
      {:signal, {:lateral_displacement, :near_zero}, 0.2}
    ]

    changed = [
      {:signal, {:route_progress, :between}, 1.0},
      {:signal, {:route_velocity, :positive}, 0.6},
      {:signal, {:nearby_transit_body, "tess", :ahead, :nearby}, 0.5}
    ]

    sensed = DevelopmentalSensorimotorLoop.sense(loop, prior)
    experience = InTransitDecision.experience_metrics(sensed, changed)

    assert experience.change == 1.0
    assert experience.repetition == 0.0
    assert experience.credit > 0.0

    refute Enum.any?(Map.keys(experience), &(&1 in [:curiosity, :boredom, :destination]))
  end
end
