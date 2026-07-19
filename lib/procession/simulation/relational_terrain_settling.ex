defmodule Procession.Simulation.RelationalTerrainSettling do
  @moduledoc """
  Builds and settles a bounded local numeric problem from `RelationalTerrain`.

  The terrain remains authoritative over identity, persistence, dimensions, and
  neighborhood selection. The configured relaxer receives only local coordinates
  and weighted distance constraints, making the numerical kernel replaceable by
  a future native implementation.
  """

  alias Procession.Simulation.RelationalTerrain.{Region, State}
  alias Procession.Simulation.TerrainRelaxer.Elixir, as: ElixirRelaxer

  @type metrics :: %{
          region_count: non_neg_integer(),
          constraint_count: non_neg_integer(),
          dimensions: pos_integer(),
          residual_before: float(),
          residual_after: float(),
          residual_reduction: float(),
          iterations: non_neg_integer(),
          elapsed_microseconds: non_neg_integer()
        }

  def settle(%State{} = state, opts \\ []) do
    ids = neighborhood_ids(state, opts)
    constraints = constraints(state, ids, opts)
    coordinates = Map.new(ids, fn id -> {id, Map.fetch!(state.regions, id).center} end)
    fixed = fixed_ids(state, ids, opts)
    problem = %{coordinates: coordinates, constraints: constraints, fixed: fixed}
    before = residual(coordinates, constraints)
    relaxer = Keyword.get(opts, :relaxer, ElixirRelaxer)
    relax_opts = Keyword.get(opts, :relaxer_opts, [])

    {elapsed, result} = :timer.tc(fn -> relaxer.relax(problem, relax_opts) end)

    regions =
      Enum.reduce(result.coordinates, state.regions, fn {id, center}, acc ->
        Map.update!(acc, id, fn %Region{} = region -> %{region | center: center} end)
      end)

    reduction = if before <= 0.0, do: 0.0, else: (before - result.residual) / before

    metrics = %{
      region_count: map_size(coordinates),
      constraint_count: length(constraints),
      dimensions: state.dimensions,
      residual_before: before,
      residual_after: result.residual,
      residual_reduction: reduction,
      iterations: result.iterations,
      elapsed_microseconds: elapsed
    }

    {%{state | regions: regions}, metrics}
  end

  defp neighborhood_ids(%State{} = state, opts) do
    max_regions = Keyword.get(opts, :max_regions, 32)
    hops = max(Keyword.get(opts, :hops, 2), 0)
    seeds = seed_ids(state)

    {visited, _frontier} =
      Enum.reduce(1..max(hops, 1), {seeds, seeds}, fn step, {visited, frontier} ->
        if step > hops do
          {visited, MapSet.new()}
        else
          next =
            frontier
            |> Enum.flat_map(&neighbors(state, &1))
            |> MapSet.new()
            |> MapSet.difference(visited)

          {MapSet.union(visited, next), next}
        end
      end)

    visited
    |> Enum.sort()
    |> Enum.take(max_regions)
  end

  defp seed_ids(%State{last_observed_region: id}) when not is_nil(id), do: MapSet.new([id])

  defp seed_ids(%State{active_region_ids: ids, regions: regions}) do
    if MapSet.size(ids) > 0 do
      ids
    else
      regions |> Map.keys() |> Enum.take(1) |> MapSet.new()
    end
  end

  defp neighbors(state, id) do
    outgoing = state.regions |> Map.fetch!(id) |> Map.get(:geometry) |> Map.keys()

    incoming =
      state.regions
      |> Enum.filter(fn {_other_id, region} -> Map.has_key?(region.geometry, id) end)
      |> Enum.map(&elem(&1, 0))

    outgoing ++ incoming
  end

  defp constraints(state, ids, opts) do
    id_set = MapSet.new(ids)
    base_distance = Keyword.get(opts, :desired_distance, Keyword.get(opts, :placement_step, 0.35))
    compression = Keyword.get(opts, :deformation_compression, 0.08)
    minimum_distance = Keyword.get(opts, :minimum_distance, base_distance * 0.25)
    minimum_weight = Keyword.get(opts, :minimum_weight, 0.01)

    ids
    |> Enum.flat_map(fn source ->
      state.regions
      |> Map.fetch!(source)
      |> Map.get(:geometry)
      |> Enum.filter(fn {target, weight} -> MapSet.member?(id_set, target) and weight >= minimum_weight end)
      |> Enum.map(fn {target, weight} ->
        distance = max(minimum_distance, base_distance / (1.0 + compression * :math.log(1.0 + weight)))
        %{source: source, target: target, distance: distance, weight: weight}
      end)
    end)
  end

  defp fixed_ids(state, ids, opts) do
    case Keyword.get(opts, :fixed, :source) do
      :none -> MapSet.new()
      :source when not is_nil(state.last_observed_region) -> MapSet.new([state.last_observed_region])
      explicit when is_list(explicit) -> explicit |> Enum.filter(&(&1 in ids)) |> MapSet.new()
      %MapSet{} = explicit -> MapSet.intersection(explicit, MapSet.new(ids))
      _ -> MapSet.new()
    end
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

  defp distance(left, right) do
    left
    |> Enum.zip(right)
    |> Enum.reduce(0.0, fn {a, b}, sum -> sum + (a - b) * (a - b) end)
    |> :math.sqrt()
  end
end
