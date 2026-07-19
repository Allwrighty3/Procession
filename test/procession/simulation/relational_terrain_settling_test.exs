defmodule Procession.Simulation.RelationalTerrainSettlingTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationalTerrain
  alias Procession.Simulation.RelationalTerrainSettling

  @opts [
    dimensions: 2,
    deformation_rate: 0.18,
    placement_step: 0.35,
    encoding_salt: :settling_test,
    auto_expand_dimensions: false,
    reuse_radius: 0.001
  ]

  test "settles only a bounded local neighborhood and reports measurable improvement" do
    terrain = train(Enum.map(1..50, &{:point, &1}), 8)
    terrain = RelationalTerrain.observe(terrain, {:point, 25}, @opts)

    {settled, metrics} =
      RelationalTerrainSettling.settle(terrain,
        max_regions: 12,
        hops: 2,
        relaxer_opts: [iterations: 8, rate: 0.25]
      )

    assert metrics.region_count <= 12
    assert metrics.region_count < RelationalTerrain.region_count(terrain)
    assert metrics.constraint_count > 0
    assert metrics.residual_after < metrics.residual_before
    assert metrics.residual_reduction > 0.0
    assert metrics.elapsed_microseconds >= 0
    assert RelationalTerrain.region_count(settled) == RelationalTerrain.region_count(terrain)
  end

  test "settling preserves cue-driven route replay" do
    terrain = train([:a, :b, :c, :d], 60)
    terrain = RelationalTerrain.observe(terrain, :b, @opts)
    {terrain, metrics} = RelationalTerrainSettling.settle(terrain, relaxer_opts: [iterations: 6, rate: 0.20])

    assert metrics.residual_after <= metrics.residual_before

    terrain = terrain |> RelationalTerrain.clear_activity() |> RelationalTerrain.observe(:a, @opts)
    step1 = RelationalTerrain.advance(terrain, @opts)
    step2 = RelationalTerrain.advance(step1, @opts)
    step3 = RelationalTerrain.advance(step2, @opts)

    assert RelationalTerrain.activation(step1, :b) > RelationalTerrain.activation(step1, :c)
    assert RelationalTerrain.activation(step2, :c) > RelationalTerrain.activation(step2, :d)
    assert RelationalTerrain.activation(step3, :d) > 0.05
  end

  defp train(route, repetitions) do
    Enum.reduce(1..repetitions, RelationalTerrain.new(@opts), fn _, terrain ->
      terrain = RelationalTerrain.clear_activity(terrain)
      Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, @opts))
    end)
  end
end
