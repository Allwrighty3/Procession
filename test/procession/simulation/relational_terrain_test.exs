defmodule Procession.Simulation.RelationalTerrainTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationalTerrain

  @opts [dimensions: 12, deformation_rate: 0.18, activity_retention: 0.12,
    flow_fraction: 0.90, active_threshold: 0.03, encoding_salt: :terrain_test]

  test "uses more than three dimensions without exposing a 3D assumption" do
    terrain = RelationalTerrain.new(@opts) |> RelationalTerrain.observe(:a, @opts)
    region = RelationalTerrain.local_region(terrain, :a)

    assert length(region.center) == 12
  end

  test "repeated similar trajectories reuse local regions instead of growing per experience" do
    terrain = train([:a, :b, :c, :d], 60)

    assert RelationalTerrain.region_count(terrain) == 4
    assert RelationalTerrain.deformation(terrain, :a, :b) > 5.0
    assert RelationalTerrain.deformation(terrain, :b, :a) < RelationalTerrain.deformation(terrain, :a, :b)
  end

  test "cleared terrain replays an ordered route through local deformation" do
    terrain = train([:a, :b, :c, :d], 60) |> RelationalTerrain.clear_activity()
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
    terrain = train(route, 4) |> RelationalTerrain.clear_activity()
    terrain = RelationalTerrain.observe(terrain, hd(route), @opts)
    terrain = Enum.reduce(1..4, terrain, fn _, acc -> RelationalTerrain.advance(acc, @opts) end)

    assert RelationalTerrain.region_count(terrain) == 80
    assert RelationalTerrain.active_region_count(terrain) < 12
  end

  defp train(route, repetitions) do
    Enum.reduce(1..repetitions, RelationalTerrain.new(@opts), fn _, terrain ->
      terrain = RelationalTerrain.clear_activity(terrain)
      Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, @opts))
    end)
  end
end
