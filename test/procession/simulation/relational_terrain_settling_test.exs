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
    terrain = terrain |> RelationalTerrain.clear_activity() |> RelationalTerrain.observe({:point, 25}, @opts)

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

  test "settling preserves cue-driven destination reachability without requiring an exact route" do
    terrain = train([:a, :b, :c, :d], 60)
    terrain = terrain |> RelationalTerrain.clear_activity() |> RelationalTerrain.observe(:b, @opts)
    {terrain, metrics} = RelationalTerrainSettling.settle(terrain, relaxer_opts: [iterations: 6, rate: 0.20])

    assert metrics.constraint_count > 0
    assert metrics.residual_before >= 0.0
    assert metrics.residual_after >= 0.0

    behavior = destination_behavior(terrain, :a, :d, 8, @opts)

    assert behavior.destination_reached
    assert behavior.arrival_tick != nil
    assert behavior.peak_destination_activation > 0.05
    assert behavior.cumulative_destination_activation >= behavior.peak_destination_activation
    assert behavior.peak_active_regions <= RelationalTerrain.region_count(terrain)
  end

  defp train(route, repetitions) do
    Enum.reduce(1..repetitions, RelationalTerrain.new(@opts), fn _, terrain ->
      terrain = RelationalTerrain.clear_activity(terrain)
      Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, @opts))
    end)
  end

  defp destination_behavior(terrain, cue, destination, horizon, opts) do
    threshold = 0.03
    terrain = terrain |> RelationalTerrain.clear_activity() |> RelationalTerrain.observe(cue, opts)

    result =
      Enum.reduce(1..horizon, %{
        terrain: terrain,
        arrival_tick: nil,
        peak_destination_activation: 0.0,
        cumulative_destination_activation: 0.0,
        peak_active_regions: RelationalTerrain.active_region_count(terrain)
      }, fn tick, acc ->
        next = RelationalTerrain.advance(acc.terrain, opts)
        activation = RelationalTerrain.activation(next, destination)

        %{
          terrain: next,
          arrival_tick: acc.arrival_tick || if(activation >= threshold, do: tick),
          peak_destination_activation: max(acc.peak_destination_activation, activation),
          cumulative_destination_activation: acc.cumulative_destination_activation + activation,
          peak_active_regions: max(acc.peak_active_regions, RelationalTerrain.active_region_count(next))
        }
      end)

    Map.put(result, :destination_reached, not is_nil(result.arrival_tick))
  end
end
