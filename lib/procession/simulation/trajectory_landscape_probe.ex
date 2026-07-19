defmodule Procession.Simulation.TrajectoryLandscapeProbe do
  @moduledoc """
  Tests whether the developmental field behaves like a deformable trajectory landscape.
  """

  alias Procession.Simulation.DevelopmentalField

  @route_a [:a, :b, :c, :d]
  @route_b [:a, :b, :e, :f]

  @opts [
    micro_nodes: 256,
    input_width: 4,
    activity_retention: 0.72,
    edge_retention: 0.9995,
    plasticity_threshold: 0.18,
    temporal_source_threshold: 0.18,
    temporal_evidence_weight: 2.0,
    coactive_evidence_weight: 1.0,
    plasticity_fanout: 8,
    plasticity_budget: 0.08,
    consolidation_threshold: 4,
    coherence_threshold: 0.06,
    reuse_threshold: 0.50,
    minimum_compression_gain: 2.0,
    encoding_salt: :trajectory_landscape_probe
  ]

  def run(opts \\ []) do
    repetitions = Keyword.get(opts, :repetitions, 40)
    idle_ticks = Keyword.get(opts, :idle_ticks, 80)

    single = train_routes([@route_a], repetitions)
    branched = train_routes([@route_a, @route_b], repetitions)
    rested = idle(single, idle_ticks)

    %{
      repetitions: repetitions,
      idle_ticks: idle_ticks,
      single: inspect_field(single),
      branched: inspect_field(branched),
      rested: inspect_field(rested),
      single_probe: probe(single, :a, [:b, :c, :d]),
      branched_probe: probe(branched, :a, [:b, :c, :d, :e, :f]),
      route_edges: %{
        single_forward: route_edge_strength(single, @route_a),
        single_reverse: route_edge_strength(single, Enum.reverse(@route_a)),
        single_skip: edge_strength(single, :a, :d),
        branched_shared: edge_strength(branched, :a, :b),
        branched_left: route_edge_strength(branched, [:b, :c, :d]),
        branched_right: route_edge_strength(branched, [:b, :e, :f]),
        rested_forward: route_edge_strength(rested, @route_a)
      }
    }
  end

  def report(result) do
    edges = result.route_edges

    [
      "Developmental field trajectory landscape probe",
      "repetitions=#{result.repetitions} idle_ticks=#{result.idle_ticks}",
      "single_forward=#{fmt(edges.single_forward)} single_reverse=#{fmt(edges.single_reverse)} single_skip=#{fmt(edges.single_skip)}",
      "branched_shared=#{fmt(edges.branched_shared)} branched_left=#{fmt(edges.branched_left)} branched_right=#{fmt(edges.branched_right)}",
      "rested_forward=#{fmt(edges.rested_forward)} retention_ratio=#{fmt(ratio(edges.rested_forward, edges.single_forward))}",
      "single_probe=#{format_probe(result.single_probe)}",
      "branched_probe=#{format_probe(result.branched_probe)}",
      "single_nodes=#{result.single.generated_nodes} single_edges=#{result.single.edge_count} single_edge_mass=#{fmt(result.single.edge_mass)}",
      "branched_nodes=#{result.branched.generated_nodes} branched_edges=#{result.branched.edge_count} branched_edge_mass=#{fmt(result.branched.edge_mass)}"
    ]
    |> Enum.join("\n")
  end

  defp train_routes(routes, repetitions) do
    Enum.reduce(1..repetitions, DevelopmentalField.new(@opts), fn _, field ->
      Enum.reduce(routes, field, fn route, route_field ->
        Enum.reduce(route, route_field, fn symbol, acc ->
          DevelopmentalField.step(acc, {:trajectory_symbol, symbol}, @opts)
        end)
      end)
    end)
  end

  defp idle(field, ticks) do
    Enum.reduce(1..ticks, field, fn tick, acc ->
      DevelopmentalField.step(acc, {:idle, tick}, @opts)
    end)
  end

  defp probe(field, cue, targets) do
    cued = DevelopmentalField.step(field, {:trajectory_symbol, cue}, @opts)

    {samples, _field} =
      Enum.map_reduce(1..4, cued, fn tick, acc ->
        next = DevelopmentalField.step(acc, {:probe_idle, tick}, @opts)
        sample = Map.new(targets, fn target -> {target, activation(next, target)} end)
        {sample, next}
      end)

    Map.new(targets, fn target ->
      values = Enum.map(samples, &Map.fetch!(&1, target))
      {target, Enum.max(values, fn -> 0.0 end)}
    end)
  end

  defp activation(field, symbol) do
    field
    |> target_nodes(symbol)
    |> Enum.map(&Map.get(field.activity, &1, 0.0))
    |> mean()
  end

  defp route_edge_strength(field, route) do
    route
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [source, target] -> edge_strength(field, source, target) end)
    |> mean()
  end

  defp edge_strength(field, source, target) do
    sources = target_nodes(field, source)
    targets = target_nodes(field, target)

    values =
      for source_id <- sources,
          target_id <- targets,
          do: Map.get(field.edges, {source_id, target_id}, 0.0)

    mean(values)
  end

  defp target_nodes(field, symbol),
    do: DevelopmentalField.active_micro_nodes(field, {:trajectory_symbol, symbol}, @opts)

  defp inspect_field(field) do
    %{
      generated_nodes: MapSet.size(field.generated),
      edge_count: map_size(field.edges),
      edge_mass: DevelopmentalField.edge_mass(field.edges)
    }
  end

  defp format_probe(probe) do
    probe
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map_join(",", fn {symbol, value} -> "#{symbol}:#{fmt(value)}" end)
  end

  defp ratio(_value, 0.0), do: 0.0
  defp ratio(value, baseline), do: value / baseline
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end
