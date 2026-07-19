defmodule Mix.Tasks.Procession.Metrics.TerrainRelaxer do
  use Mix.Task

  alias Procession.Simulation.TerrainRelaxer.Elixir, as: Relaxer

  @shortdoc "Benchmarks local relational-terrain relaxation"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    for regions <- [8, 16, 32], dimensions <- [1, 8, 32], iterations <- [1, 4] do
      problem = problem(regions, dimensions)
      {microseconds, result} = :timer.tc(fn -> Relaxer.relax(problem, iterations: iterations) end)

      Mix.shell().info(
        "regions=#{regions} dimensions=#{dimensions} iterations=#{iterations} " <>
          "time_us=#{microseconds} residual=#{Float.round(result.residual, 6)}"
      )
    end
  end

  defp problem(region_count, dimensions) do
    ids = Enum.to_list(0..(region_count - 1))

    coordinates =
      Map.new(ids, fn id ->
        coordinate = Enum.map(0..(dimensions - 1), fn axis -> rem(id + axis, 7) / 3.0 end)
        {id, coordinate}
      end)

    constraints =
      ids
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [source, target] ->
        %{source: source, target: target, distance: 1.0, weight: 1.0}
      end)

    %{coordinates: coordinates, constraints: constraints, fixed: MapSet.new([0])}
  end
end
