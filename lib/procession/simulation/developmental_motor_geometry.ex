defmodule Procession.Simulation.DevelopmentalMotorGeometry do
  @moduledoc """
  Shared physical geometry for opaque developmental motor patterns.

  The values describe combined body-force vectors only. They do not assign goals,
  actions, or meanings to motor patterns.
  """

  @channel_forces %{
    m1: {-0.42, -0.18},
    m2: {0.38, -0.22},
    m3: {-0.20, 0.44},
    m4: {0.24, 0.40},
    m5: {-0.34, 0.16},
    m6: {0.36, 0.12},
    m7: {-0.08, -0.38},
    m8: {0.10, 0.36}
  }

  def pattern_force({a, b}) do
    {ax, ay} = Map.fetch!(@channel_forces, a)
    {bx, by} = Map.fetch!(@channel_forces, b)
    {ax + bx, ay + by}
  end

  def route_projection({x, y}, :east), do: {x, y}
  def route_projection({x, y}, :west), do: {-x, y}
  def route_projection({_x, y}, _direction), do: {0.0, y}
end
