defmodule Procession.Simulation.TerrainRelaxer.Elixir do
  @moduledoc """
  Reference Elixir implementation of local terrain relaxation.

  The algorithm is deliberately small and transparent: each pass accumulates
  pairwise distance corrections, then applies them simultaneously. Established
  constraints move the neighborhood according to their weight while fixed
  regions remain anchored.
  """

  @behaviour Procession.Simulation.TerrainRelaxer

  @impl true
  def relax(%{coordinates: coordinates, constraints: constraints} = problem, opts \\ []) do
    fixed = Map.get(problem, :fixed, MapSet.new())
    iterations = Keyword.get(opts, :iterations, 2)
    rate = Keyword.get(opts, :rate, 0.20)
    epsilon = Keyword.get(opts, :epsilon, 1.0e-9)

    final =
      Enum.reduce(1..iterations, coordinates, fn _, current ->
        corrections = accumulate_corrections(current, constraints, fixed, epsilon)
        apply_corrections(current, corrections, rate)
      end)

    %{
      coordinates: final,
      residual: residual(final, constraints),
      iterations: iterations
    }
  end

  defp accumulate_corrections(coordinates, constraints, fixed, epsilon) do
    Enum.reduce(constraints, %{}, fn constraint, acc ->
      source = constraint.source
      target = constraint.target
      source_position = Map.fetch!(coordinates, source)
      target_position = Map.fetch!(coordinates, target)
      delta = subtract(target_position, source_position)
      actual = magnitude(delta)
      desired = constraint.distance
      weight = constraint.weight
      direction = if actual <= epsilon, do: fallback_direction(length(delta)), else: scale(delta, 1.0 / actual)
      correction = scale(direction, (actual - desired) * weight * 0.5)

      acc
      |> maybe_add(source, correction, fixed)
      |> maybe_add(target, scale(correction, -1.0), fixed)
    end)
  end

  defp maybe_add(acc, id, correction, fixed) do
    if MapSet.member?(fixed, id) do
      acc
    else
      Map.update(acc, id, correction, &add(&1, correction))
    end
  end

  defp apply_corrections(coordinates, corrections, rate) do
    Map.new(coordinates, fn {id, position} ->
      movement = corrections |> Map.get(id, List.duplicate(0.0, length(position))) |> scale(rate)
      {id, add(position, movement)}
    end)
  end

  defp residual(_coordinates, []), do: 0.0

  defp residual(coordinates, constraints) do
    total =
      Enum.reduce(constraints, 0.0, fn constraint, sum ->
        actual = distance(Map.fetch!(coordinates, constraint.source), Map.fetch!(coordinates, constraint.target))
        error = actual - constraint.distance
        sum + error * error * constraint.weight
      end)

    :math.sqrt(total / length(constraints))
  end

  defp fallback_direction(0), do: []
  defp fallback_direction(dimensions), do: [1.0 | List.duplicate(0.0, dimensions - 1)]
  defp add(left, right), do: Enum.zip_with(left, right, &(&1 + &2))
  defp subtract(left, right), do: Enum.zip_with(left, right, &(&1 - &2))
  defp scale(vector, amount), do: Enum.map(vector, &(&1 * amount))
  defp magnitude(vector), do: :math.sqrt(Enum.reduce(vector, 0.0, fn value, sum -> sum + value * value end))
  defp distance(left, right), do: left |> subtract(right) |> magnitude()
end
