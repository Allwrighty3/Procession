defmodule Mix.Tasks.Procession.Metrics.RelationalTerrainCompression do
  use Mix.Task

  alias Procession.Simulation.RelationalTerrain
  alias Procession.Simulation.RelationalTerrainCompression

  @shortdoc "Reports internal candidate compression across practice and disturbances"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    opts = [dimensions: 8, deformation_rate: 0.18, reverse_deformation_ratio: 0.10,
      auto_expand_dimensions: false, reuse_radius: 0.001, encoding_salt: :compression_metric]

    IO.puts("Relational terrain internal compression metrics")

    for route_size <- [32, 64, 128, 256], repetitions <- [1, 5, 20, 100] do
      route = Enum.map(1..route_size, &{{:compression, route_size}, &1})
      terrain = train(route, repetitions, opts)
      result = RelationalTerrainCompression.analyze(terrain, route)

      print_result("stable", route_size, repetitions, result)
    end

    route = Enum.map(1..128, &{{:disturbed, 128}, &1})
    terrain = train(route, 100, opts)

    for disturbance <- [nil, Enum.at(route, 31), Enum.at(route, 63), Enum.at(route, 95)] do
      result =
        RelationalTerrainCompression.analyze(terrain, route,
          disturbances: if(is_nil(disturbance), do: [], else: [disturbance])
        )

      print_result(if(is_nil(disturbance), do: "undisturbed", else: "disturbed"), 128, 100, result,
        disturbance: disturbance)
    end
  end

  defp print_result(kind, route_size, repetitions, result, extra \\ []) do
    sizes = Enum.map(result.assemblies, &length(&1.members))
    consolidations = Enum.map(result.assemblies, & &1.consolidation)

    IO.puts(Enum.join([
      "kind=#{kind}",
      "route_size=#{route_size}",
      "repetitions=#{repetitions}",
      "assemblies=#{result.assembly_count}",
      "assembly_sizes=#{inspect(sizes, charlists: :as_lists)}",
      "largest_assembly=#{Enum.max(sizes, fn -> 0 end)}",
      "mean_consolidation=#{format(mean(consolidations))}",
      "compressed_members=#{result.compressed_members}",
      "detailed_transitions=#{result.detailed_transitions}",
      "compressed_transitions=#{result.compressed_transitions}",
      "transitions_saved=#{result.transitions_saved}",
      "compression_ratio=#{format(result.compression_ratio)}",
      "disturbance=#{inspect(Keyword.get(extra, :disturbance))}"
    ], " "))

    Enum.each(result.assemblies, fn assembly ->
      IO.puts(Enum.join([
        "assembly=#{assembly.id}",
        "entry=#{inspect(assembly.entry)}",
        "exit=#{inspect(assembly.exit)}",
        "members=#{length(assembly.members)}",
        "minimum_support=#{format(assembly.minimum_support)}",
        "minimum_dominance=#{format(assembly.minimum_dominance)}",
        "consolidation=#{format(assembly.consolidation)}",
        "saved=#{assembly.detailed_transitions - assembly.compressed_transitions}"
      ], " "))
    end)
  end

  defp train(route, repetitions, opts) do
    Enum.reduce(1..repetitions, RelationalTerrain.new(opts), fn _, terrain ->
      terrain = RelationalTerrain.clear_activity(terrain)
      Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, opts))
    end)
  end

  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end
