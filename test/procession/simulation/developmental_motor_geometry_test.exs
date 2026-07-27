defmodule Procession.Simulation.DevelopmentalMotorGeometryTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalMotorGeometry

  test "route projection preserves forward, reverse, and transverse force" do
    force = DevelopmentalMotorGeometry.pattern_force({:m2, :m6})
    {eastward, east_lateral} = DevelopmentalMotorGeometry.route_projection(force, :east)
    {westward, west_lateral} = DevelopmentalMotorGeometry.route_projection(force, :west)

    assert eastward > 0.0
    assert westward < 0.0
    assert east_lateral == west_lateral
  end
end
