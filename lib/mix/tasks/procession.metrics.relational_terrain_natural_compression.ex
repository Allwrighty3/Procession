defmodule Mix.Tasks.Procession.Metrics.RelationalTerrainNaturalCompression do
  use Mix.Task

  alias Procession.Simulation.RelationalTerrainNaturalCompression, as: NaturalCompression

  @shortdoc "Measures terrain-owned natural motif discovery and compression"
  @route_sizes [32, 64, 128]
  @repetitions [5, 20, 100]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    IO.puts("Relational terrain natural compression metrics")

    for route_size <- @route_sizes, repetitions <- @repetitions do
      route = Enum.map(1..route_size, &{{:natural, route_size}, &1})
      state = train(route, repetitions)
      instrumentation = NaturalCompression.instrumentation(state)
      plan = NaturalCompression.compression_plan(state, route)

      IO.puts(
        Enum.join([
          "route_size=#{route_size}",
          "repetitions=#{repetitions}",
          "tracked_motifs=#{instrumentation.tracked_motifs}",
          "assembly_count=#{instrumentation.assembly_count}",
          "assemblies_by_size=#{format_sizes(instrumentation.assemblies_by_size)}",
          "maximum_assembly_size=#{instrumentation.maximum_assembly_size}",
          "assemblies_used=#{length(plan.assemblies_used)}",
          "detailed_transitions=#{plan.detailed_transitions}",
          "effective_transitions=#{plan.effective_transitions}",
          "transitions_saved=#{plan.transitions_saved}",
          "compression_ratio=#{format(plan.compression_ratio)}"
        ], " ")
      )
    end

    disturbance_metrics()
    overlap_metrics()
  end

  defp disturbance_metrics do
    route = Enum.map(1..128, &{{:disturbance, 128}, &1})
    state = train(route, 100)
    baseline = NaturalCompression.compression_plan(state, route)
    disturbance = Enum.at(route, 63)
    disturbed = NaturalCompression.compression_plan(state, route, disturbances: [disturbance])

    IO.puts(
      Enum.join([
        "scenario=disturbance",
        "route_size=128",
        "disturbance=#{inspect(disturbance)}",
        "baseline_saved=#{baseline.transitions_saved}",
        "disturbed_saved=#{disturbed.transitions_saved}",
        "baseline_assemblies=#{length(baseline.assemblies_used)}",
        "disturbed_assemblies=#{length(disturbed.assemblies_used)}",
        "disturbed_ratio=#{format(disturbed.compression_ratio)}"
      ], " ")
    )
  end

  defp overlap_metrics do
    shared = Enum.map(1..8, &{:shared, &1})
    left = [{:left, 1}, {:left, 2}] ++ shared ++ [{:left, 3}, {:left, 4}]
    right = [{:right, 1}, {:right, 2}] ++ shared ++ [{:right, 3}, {:right, 4}]

    state =
      Enum.reduce(1..40, NaturalCompression.new(opts(:overlap)), fn _, acc ->
        acc
        |> traverse(left, opts(:overlap))
        |> NaturalCompression.clear_activity()
        |> traverse(right, opts(:overlap))
        |> NaturalCompression.clear_activity()
      end)

    shared_count = NaturalCompression.motif_count(state, shared)
    shared_discovered = Enum.any?(NaturalCompression.assemblies(state), &(&1.members == shared))

    IO.puts(
      Enum.join([
        "scenario=overlap",
        "shared_size=8",
        "shared_occurrences=#{format(shared_count)}",
        "shared_discovered=#{shared_discovered}",
        "assembly_count=#{NaturalCompression.instrumentation(state).assembly_count}"
      ], " ")
    )
  end

  defp train(route, repetitions) do
    scenario_opts = opts({:route, length(route)})

    Enum.reduce(1..repetitions, NaturalCompression.new(scenario_opts), fn _, state ->
      state |> traverse(route, scenario_opts) |> NaturalCompression.clear_activity()
    end)
  end

  defp traverse(state, route, scenario_opts),
    do: Enum.reduce(route, state, &NaturalCompression.observe(&2, &1, scenario_opts))

  defp opts(salt) do
    [
      dimensions: 8,
      deformation_rate: 0.18,
      placement_step: 0.35,
      activity_retention: 0.12,
      flow_fraction: 0.90,
      active_threshold: 0.03,
      auto_expand_dimensions: false,
      reuse_radius: 0.001,
      encoding_salt: {:natural_compression, salt}
    ]
  end

  defp format_sizes(sizes) do
    sizes
    |> Enum.sort()
    |> Enum.map_join(",", fn {size, count} -> "#{size}:#{count}" end)
    |> case do
      "" -> "none"
      value -> value
    end
  end

  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end
