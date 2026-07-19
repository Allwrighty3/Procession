defmodule Procession.Simulation.RelationalTerrainTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationalTerrain

  @opts [dimensions: 12, deformation_rate: 0.18, activity_retention: 0.12,
    flow_fraction: 0.90, active_threshold: 0.03, encoding_salt: :terrain_test,
    placement_step: 0.40, placement_learning_rate: 0.05]

  test "supports arbitrary positive dimensionality without a 3D assumption" do
    one_d = RelationalTerrain.new(dimensions: 1) |> RelationalTerrain.observe(:a, dimensions: 1)
    twelve_d = RelationalTerrain.new(@opts) |> RelationalTerrain.observe(:a, @opts)

    assert length(RelationalTerrain.local_region(one_d, :a).center) == 1
    assert length(RelationalTerrain.local_region(twelve_d, :a).center) == 12
    assert_raise ArgumentError, fn -> RelationalTerrain.new(dimensions: 0) end
  end

  test "one dimensional terrain can still form and replay a directional route" do
    opts = Keyword.merge(@opts, dimensions: 1, encoding_salt: :one_dimensional_terrain)
    terrain = train([:a, :b, :c, :d], 60, opts) |> RelationalTerrain.clear_activity()
    terrain = RelationalTerrain.observe(terrain, :a, opts)

    step1 = RelationalTerrain.advance(terrain, opts)
    step2 = RelationalTerrain.advance(step1, opts)
    step3 = RelationalTerrain.advance(step2, opts)

    assert RelationalTerrain.deformation(terrain, :a, :b) > RelationalTerrain.deformation(terrain, :b, :a)
    assert RelationalTerrain.activation(step1, :b) > RelationalTerrain.activation(step1, :c)
    assert RelationalTerrain.activation(step2, :c) > RelationalTerrain.activation(step2, :d)
    assert RelationalTerrain.activation(step3, :d) > 0.05
  end

  test "new region placement is local to recent experience rather than a global hash position" do
    terrain =
      RelationalTerrain.new(@opts)
      |> RelationalTerrain.observe(:a, @opts)
      |> RelationalTerrain.observe(:b, @opts)
      |> RelationalTerrain.observe(:c, @opts)

    a = RelationalTerrain.local_region(terrain, :a).center
    b = RelationalTerrain.local_region(terrain, :b).center
    c = RelationalTerrain.local_region(terrain, :c).center

    assert distance(a, b) < 0.50
    assert distance(b, c) < 0.50
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
      Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, opts))
    end)
  end

  defp distance(left, right) do
    left
    |> Enum.zip(right)
    |> Enum.reduce(0.0, fn {a, b}, total -> total + :math.pow(a - b, 2) end)
    |> :math.sqrt()
  end
end