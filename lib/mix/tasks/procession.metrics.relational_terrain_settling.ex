defmodule Mix.Tasks.Procession.Metrics.RelationalTerrainSettling do
  use Mix.Task

  alias Procession.Simulation.RelationalTerrain
  alias Procession.Simulation.RelationalTerrainSettling

  @shortdoc "Measures terrain relaxation and destination behavior across dimensions and route lengths"

  @dimensions [1, 8, 32]
  @route_sizes [16, 32, 64]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    IO.puts("Relational terrain dimension/route-length matrix")

    for dimensions <- @dimensions, route_size <- @route_sizes do
      scenario = %{
        name: "chain_#{dimensions}d_#{route_size}",
        dimensions: dimensions,
        route_size: route_size,
        max_regions: 24
      }

      metrics = run_scenario(scenario)

      IO.puts(
        Enum.join([
          "scenario=#{scenario.name}",
          "dimensions=#{metrics.dimensions}",
          "route_size=#{scenario.route_size}",
          "stored_regions=#{metrics.stored_regions}",
          "settled_regions=#{metrics.region_count}",
          "constraints=#{metrics.constraint_count}",
          "residual_before=#{format(metrics.residual_before)}",
          "residual_after=#{format(metrics.residual_after)}",
          "reduction_pct=#{format(metrics.residual_reduction * 100.0)}",
          "elapsed_us=#{metrics.elapsed_microseconds}",
          "destination_reached=#{metrics.destination_reached}",
          "arrival_tick=#{format_tick(metrics.arrival_tick)}",
          "destination_peak=#{format(metrics.peak_destination_activation)}",
          "destination_cumulative=#{format(metrics.cumulative_destination_activation)}",
          "peak_active_regions=#{metrics.peak_active_regions}"
        ], " ")
      )
    end
  end

  defp run_scenario(scenario) do
    opts = [
      dimensions: scenario.dimensions,
      deformation_rate: 0.18,
      placement_step: 0.35,
      activity_retention: 0.12,
      flow_fraction: 0.90,
      active_threshold: 0.03,
      auto_expand_dimensions: false,
      reuse_radius: 0.001,
      encoding_salt: {:settling_matrix, scenario.dimensions}
    ]

    route = Enum.map(1..scenario.route_size, &{{:matrix, scenario.dimensions}, &1})
    terrain = train(route, 20, opts)
    middle = Enum.at(route, div(length(route), 2))
    terrain = terrain |> RelationalTerrain.clear_activity() |> RelationalTerrain.observe(middle, opts)

    {terrain, metrics} =
      RelationalTerrainSettling.settle(terrain,
        max_regions: scenario.max_regions,
        hops: 3,
        relaxer_opts: [iterations: 8, rate: 0.25]
      )

    behavior = destination_behavior(terrain, hd(route), List.last(route), length(route) + 8, opts)

    metrics
    |> Map.merge(behavior)
    |> Map.put(:stored_regions, RelationalTerrain.region_count(terrain))
  end

  defp train(route, repetitions, opts) do
    Enum.reduce(1..repetitions, RelationalTerrain.new(opts), fn _, terrain ->
      terrain = RelationalTerrain.clear_activity(terrain)
      Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, opts))
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

    %{
      destination_reached: not is_nil(result.arrival_tick),
      arrival_tick: result.arrival_tick,
      peak_destination_activation: result.peak_destination_activation,
      cumulative_destination_activation: result.cumulative_destination_activation,
      peak_active_regions: result.peak_active_regions
    }
  end

  defp format_tick(nil), do: "none"
  defp format_tick(tick), do: Integer.to_string(tick)
  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end
