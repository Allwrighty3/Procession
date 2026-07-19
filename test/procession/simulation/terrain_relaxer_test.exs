defmodule Procession.Simulation.TerrainRelaxerTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.TerrainRelaxer.Elixir, as: Relaxer

  test "reduces local distance residual with simultaneous corrections" do
    problem = %{
      coordinates: %{a: [0.0], b: [2.0], c: [4.0]},
      constraints: [
        %{source: :a, target: :b, distance: 1.0, weight: 1.0},
        %{source: :b, target: :c, distance: 1.0, weight: 1.0}
      ],
      fixed: MapSet.new([:a])
    }

    before = residual(problem.coordinates, problem.constraints)
    result = Relaxer.relax(problem, iterations: 8, rate: 0.30)

    assert result.residual < before
    assert result.coordinates.a == [0.0]
    assert hd(result.coordinates.b) < 2.0
    assert hd(result.coordinates.c) < 4.0
  end

  test "works unchanged in higher-dimensional local neighborhoods" do
    problem = %{
      coordinates: %{
        origin: [0.0, 0.0, 0.0, 0.0],
        branch_a: [2.0, 0.0, 0.0, 0.0],
        branch_b: [0.0, 3.0, 0.0, 0.0]
      },
      constraints: [
        %{source: :origin, target: :branch_a, distance: 1.0, weight: 2.0},
        %{source: :origin, target: :branch_b, distance: 1.0, weight: 1.0}
      ],
      fixed: MapSet.new([:origin])
    }

    result = Relaxer.relax(problem, iterations: 6, rate: 0.25)

    assert Enum.all?(Map.values(result.coordinates), &(length(&1) == 4))
    assert result.residual < residual(problem.coordinates, problem.constraints)
  end

  test "an empty constraint set is a no-op" do
    coordinates = %{a: [0.0], b: [1.0]}
    result = Relaxer.relax(%{coordinates: coordinates, constraints: []})

    assert result.coordinates == coordinates
    assert result.residual == 0.0
  end

  defp residual(coordinates, constraints) do
    total =
      Enum.reduce(constraints, 0.0, fn constraint, sum ->
        actual = distance(coordinates[constraint.source], coordinates[constraint.target])
        error = actual - constraint.distance
        sum + error * error * constraint.weight
      end)

    :math.sqrt(total / length(constraints))
  end

  defp distance(left, right) do
    left
    |> Enum.zip(right)
    |> Enum.reduce(0.0, fn {a, b}, sum -> sum + :math.pow(a - b, 2) end)
    |> :math.sqrt()
  end
end
