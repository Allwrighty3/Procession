defmodule Mix.Tasks.Procession.Metrics.RelationalTerrainSettling do
  use Mix.Task

  alias Procession.Simulation.RelationalTerrain
  alias Procession.Simulation.RelationalTerrainSettling

  @shortdoc "Measures local terrain relaxation quality and cost"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    scenarios = [
      %{name: "chain_1d", dimensions: 1, route_size: 16, max_regions: 12},
      %{name: "chain_8d", dimensions: 8, route_size: 32, max_regions: 16},
      %{name: "chain_32d", dimensions: 32, route_size: 64, max_regions: 24}
    ]

    IO.puts("Relational terrain settling metrics")

    Enum.each(scenarios, fn scenario ->
      metrics = run_scenario(scenario)

      IO.puts(
        Enum.join([
          "scenario=#{scenario.name}",
          "dimensions=#{metrics.dimensions}",
          "stored_regions=#{metrics.stored_regions}",
          "settled_regions=#{metrics.region_count}",
          "constraints=#{metrics.constraint_count}",
          "residual_before=#{format(metrics.residual_before)}",
          "residual_after=#{format(metrics.residual_after)}",
          "reduction_pct=#{format(metrics.residual_reduction * 100.0)}",
          "elapsed_us=#{metrics.elapsed_microseconds}",
          "replay_score=#{format(metrics.replay_score)}"
        ], " "
        )
      )
    end)
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
      encoding_salt: {:settling_metric, scenario.name}
    ]

    route = Enum.map(1..scenario.route_size, &{scenario.name, &1})
    terrain = train(route, 20, opts)
    middle = Enum.at(route, div(length(route), 2))
    terrain = RelationalTerrain.observe(terrain, middle, opts)

    {terrain, metrics} =
      RelationalTerrainSettling.settle(terrain,
        max_regions: scenario.max_regions,
        hops: 3,
        relaxer_opts: [iterations: 8, rate: 0.25]
      )

    Map.merge(metrics, %{
      stored_regions: RelationalTerrain.region_count(terrain),
      replay_score: replay_score(terrain, route, opts)
    })
  end

  defp train(route, repetitions, opts) do
    Enum.reduce(1..repetitions, RelationalTerrain.new(opts), fn _, terrain ->
      terrain = RelationalTerrain.clear_activity(terrain)
      Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, opts))
    end)
  end

  defp replay_score(terrain, route, opts) do
    [first | expected] = route
    terrain = terrain |> RelationalTerrain.clear_activity() |> RelationalTerrain.observe(first, opts)

    {_terrain, hits} =
      Enum.reduce(expected, {terrain, 0}, fn expected_observation, {current, hits} ->
        next = RelationalTerrain.advance(current, opts)
        activation = RelationalTerrain.activation(next, expected_observation)
        {next, hits + if(activation > 0.03, do: 1, else: 0)}
      end)

    hits / max(length(expected), 1)
  end

  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end
