defmodule Procession.Simulation.RelationalTerrainTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationalTerrain

  @opts [dimensions: 12, deformation_rate: 0.18, activity_retention: 0.12,
    flow_fraction: 0.90, active_threshold: 0.03, encoding_salt: :terrain_test]

  test "one dimension is a viable manifold for a simple trajectory" do
    opts = Keyword.put(@opts, :dimensions, 1)
    terrain = train([:a, :b, :c, :d], 60, opts)

    assert RelationalTerrain.dimension_count(terrain) == 1
    assert RelationalTerrain.dimension_expansion_count(terrain) == 0
    assert length(RelationalTerrain.local_region(terrain, :a).center) == 1

    terrain = terrain |> RelationalTerrain.clear_activity() |> RelationalTerrain.observe(:a, opts)
    step1 = RelationalTerrain.advance(terrain, opts)
    step2 = RelationalTerrain.advance(step1, opts)
    step3 = RelationalTerrain.advance(step2, opts)

    assert RelationalTerrain.activation(step1, :b) > RelationalTerrain.activation(step1, :c)
    assert RelationalTerrain.activation(step2, :c) > RelationalTerrain.activation(step2, :d)
    assert RelationalTerrain.activation(step3, :d) > 0.05
  end

  test "expands only when distinct local branches collide in the current manifold" do
    opts = Keyword.merge(@opts, dimensions: 1, dimension_conflict_radius: 0.20)

    terrain =
      RelationalTerrain.new(opts)
      |> traverse([:origin, :branch_a], opts)
      |> RelationalTerrain.clear_activity()
      |> traverse([:origin, :branch_b], opts)
      |> RelationalTerrain.clear_activity()
      |> traverse([:origin, :branch_c], opts)

    assert RelationalTerrain.dimension_count(terrain) > 1
    assert RelationalTerrain.dimension_expansion_count(terrain) >= 1
    assert RelationalTerrain.region_count(terrain) == 4

    centers = Enum.map([:branch_a, :branch_b, :branch_c], &RelationalTerrain.local_region(terrain, &1).center)
    assert centers |> Enum.uniq() |> length() == 3
  end

  test "expands for directional crowding even without positional collision" do
    provider = fn
      :branch_a, 2 -> [1.0, 0.0]
      :branch_b, 2 -> [0.98, 0.20]
      _observation, dimensions -> [1.0 | List.duplicate(0.0, dimensions - 1)]
    end

    opts = Keyword.merge(@opts,
      dimensions: 2,
      direction_provider: provider,
      dimension_conflict_radius: 0.001,
      direction_crowding_cosine: 0.95,
      reuse_radius: 0.001
    )

    terrain =
      RelationalTerrain.new(opts)
      |> traverse([:origin, :branch_a], opts)
      |> RelationalTerrain.clear_activity()
      |> traverse([:origin, :branch_b], opts)

    assert RelationalTerrain.dimension_count(terrain) == 3
    assert RelationalTerrain.dimension_expansion_count(terrain) == 1

    branch_a = RelationalTerrain.local_region(terrain, :branch_a).center
    branch_b = RelationalTerrain.local_region(terrain, :branch_b).center
    assert branch_a != branch_b
    assert Enum.at(branch_b, 2) != 0.0
  end

  test "does not expand when local directions remain well separated" do
    provider = fn
      :branch_a, 2 -> [1.0, 0.0]
      :branch_b, 2 -> [0.0, 1.0]
      _observation, dimensions -> [1.0 | List.duplicate(0.0, dimensions - 1)]
    end

    opts = Keyword.merge(@opts,
      dimensions: 2,
      direction_provider: provider,
      dimension_conflict_radius: 0.001,
      direction_crowding_cosine: 0.95,
      reuse_radius: 0.001
    )

    terrain =
      RelationalTerrain.new(opts)
      |> traverse([:origin, :branch_a], opts)
      |> RelationalTerrain.clear_activity()
      |> traverse([:origin, :branch_b], opts)

    assert RelationalTerrain.dimension_count(terrain) == 2
    assert RelationalTerrain.dimension_expansion_count(terrain) == 0
  end

  test "can disable dimensional expansion for controlled comparisons" do
    opts = Keyword.merge(@opts,
      dimensions: 1,
      auto_expand_dimensions: false,
      dimension_conflict_radius: 0.20,
      reuse_radius: 0.001
    )

    terrain =
      RelationalTerrain.new(opts)
      |> traverse([:origin, :branch_a], opts)
      |> RelationalTerrain.clear_activity()
      |> traverse([:origin, :branch_b], opts)
      |> RelationalTerrain.clear_activity()
      |> traverse([:origin, :branch_c], opts)

    assert RelationalTerrain.dimension_count(terrain) == 1
    assert RelationalTerrain.dimension_expansion_count(terrain) == 0
  end

  test "uses more than three dimensions without exposing a 3D assumption" do
    terrain = RelationalTerrain.new(@opts) |> RelationalTerrain.observe(:a, @opts)
    region = RelationalTerrain.local_region(terrain, :a)

    assert length(region.center) == 12
  end

  test "rejects zero-dimensional terrain" do
    assert_raise ArgumentError, fn -> RelationalTerrain.new(dimensions: 0) end
  end

  test "repeated similar trajectories reuse local regions instead of growing per experience" do
    terrain = train([:a, :b, :c, :d], 60, @opts)

    assert RelationalTerrain.region_count(terrain) == 4
    assert RelationalTerrain.deformation(terrain, :a, :b) > 5.0
    assert RelationalTerrain.deformation(terrain, :b, :a) < RelationalTerrain.deformation(terrain, :a, :b)
  end

  test "cleared terrain replays an ordered route through local deformation" do
    terrain = train([:a, :b, :c, :d], 60, @opts) |> RelationalTerrain.clear_activity()
    terrain = RelationalTerrain.observe(terrain, :a, @opts)

    step1 = RelationalTerrain.advance(terrain, @opts)
    step2 = RelationalTerrain.advance(step1, @opts)
    step3 = RelationalTerrain.advance(step2, @opts)

    assert RelationalTerrain.activation(step1, :b) > RelationalTerrain.activation(step1, :c)
    assert RelationalTerrain.activation(step2, :c) > RelationalTerrain.activation(step2, :d)
    assert RelationalTerrain.activation(step3, :d) > 0.05
  end

  test "active working set stays local as stored terrain grows" do
    route = Enum.map(1..80, &{:point, &1})
    terrain = train(route, 4, @opts) |> RelationalTerrain.clear_activity()
    terrain = RelationalTerrain.observe(terrain, hd(route), @opts)
    terrain = Enum.reduce(1..4, terrain, fn _, acc -> RelationalTerrain.advance(acc, @opts) end)

    assert RelationalTerrain.region_count(terrain) == 80
    assert RelationalTerrain.active_region_count(terrain) < 12
  end

  defp train(route, repetitions, opts) do
    Enum.reduce(1..repetitions, RelationalTerrain.new(opts), fn _, terrain ->
      terrain = RelationalTerrain.clear_activity(terrain)
      traverse(terrain, route, opts)
    end)
  end

  defp traverse(terrain, route, opts), do: Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, opts))
end
