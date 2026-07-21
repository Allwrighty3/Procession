defmodule Procession.Simulation.RecursiveMemoryQualityExperiment do
  @moduledoc """
  Compares legacy recursive consolidation with incremental-gain and phase-specific
  output learning on a repeated four-phase routine.
  """

  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @conditions [:legacy, :quality]
  @phases [
    {:depart, :motor_a, [location: :home, carrying: false, pressure: :hunger]},
    {:arrive_resource, :motor_b, [location: :resource, carrying: false, contact: true]},
    {:return, :motor_c, [location: :away, carrying: true, pressure: :hunger]},
    {:consume, :motor_d, [location: :home, carrying: true, contact: true]}
  ]
  @outputs Enum.map(@phases, &elem(&1, 1))

  @base_opts [
    micro_nodes: 64,
    input_width: 5,
    activity_retention: 0.72,
    edge_retention: 0.999,
    output_edge_retention: 0.999,
    consolidation_threshold: 4,
    minimum_compression_gain: 0.0,
    coherence_threshold: 0.02,
    compression_node_threshold: 0.16,
    compression_coverage_threshold: 0.50,
    plasticity_threshold: 0.16,
    output_source_threshold: 0.10,
    output_plasticity_budget: 0.12,
    output_learning_scale: 0.35
  ]

  def run(opts \\ []) do
    episodes = Keyword.get(opts, :episodes, 120)
    probes = Keyword.get(opts, :probes, 40)
    seed = Keyword.get(opts, :seed, 1)

    rows = Enum.map(@conditions, &run_condition(&1, episodes, probes, seed))
    %{episodes: episodes, probes: probes, rows: rows}
  end

  def report(result) do
    lines = Enum.map(result.rows, fn row ->
      "#{row.condition}: accuracy=#{fmt(row.accuracy)} generated=#{row.generated} " <>
        "recursive=#{row.recursive} max_depth=#{row.max_depth} " <>
        "collapsed_depth=#{row.collapsed_depth} branching=#{row.branching} " <>
        "single_child=#{row.single_child} margin=#{fmt(row.margin)}"
    end)

    Enum.join([
      "Recursive memory compression-quality audit",
      "episodes=#{result.episodes} probes_per_phase=#{result.probes}",
      "legacy active-context learning vs incremental-gain/rising-residual quality gates"
      | lines
    ], "\n")
  end

  defp run_condition(condition, episodes, probes, seed) do
    opts = field_opts(condition, seed)

    trained =
      Enum.reduce(1..episodes, Field.new(opts), fn episode, field ->
        Enum.reduce(@phases, field, fn {phase, output, features}, acc ->
          sensed = Field.sense(acc, phase_features(phase, features, episode), opts)
          Field.record_output(sensed, output, 1.0, opts)
        end)
      end)

    {correct, total, margins} =
      Enum.reduce(@phases, {0, 0, []}, fn {phase, expected, features}, totals ->
        Enum.reduce(1..probes, totals, fn probe, {correct, total, margins} ->
          field = Field.sense(trained, phase_features(phase, features, episodes + probe), opts)
          scores = Field.output_scores(field, @outputs, opts)
          {selected, best} = Enum.max_by(scores, fn {output, score} -> {score, output} end)
          runner_up = scores |> Map.delete(selected) |> Map.values() |> Enum.max(fn -> 0.0 end)
          {correct + if(selected == expected, do: 1, else: 0), total + 1,
           [best - runner_up | margins]}
        end)
      end)

    structure = structure(trained.sensory)

    Map.merge(structure, %{
      condition: condition,
      accuracy: correct / max(total, 1),
      margin: mean(margins)
    })
  end

  defp phase_features(phase, features, episode) do
    [{:routine, :resource_cycle}, {:phase, phase}, {:episode_parity, rem(episode, 2)} |
      Enum.map(features, fn {key, value} -> {key, value} end)]
  end

  defp field_opts(:legacy, seed) do
    [encoding_salt: {:recursive_quality, seed}, output_source_mode: :active,
     output_specificity_power: 0.0, recursive_quality_gate: false] ++ @base_opts
  end

  defp field_opts(:quality, seed) do
    [encoding_salt: {:recursive_quality, seed}, output_source_mode: :rising_residual,
     output_specificity_power: 0.5, recursive_quality_gate: true,
     recursive_min_residual_members: 2, recursive_ancestor_penalty: 1.5,
     minimum_incremental_compression_gain: 2.0] ++ @base_opts
  end

  defp structure(sensory) do
    depths = depths(sensory)

    child_counts =
      Enum.map(sensory.generated, fn id ->
        node = Map.fetch!(sensory.nodes, id)
        Enum.count(node.support, fn member -> Map.fetch!(sensory.nodes, member).kind == :generated end)
      end)

    %{
      generated: MapSet.size(sensory.generated),
      recursive: Enum.count(depths, fn {_id, depth} -> depth >= 2 end),
      max_depth: depths |> Map.values() |> Enum.max(fn -> 0 end),
      collapsed_depth: collapsed_depth(sensory),
      branching: Enum.count(child_counts, &(&1 >= 2)),
      single_child: Enum.count(child_counts, &(&1 == 1))
    }
  end

  defp depths(sensory) do
    Enum.reduce(sensory.generated, %{}, fn id, memo ->
      {_depth, memo} = depth(id, sensory, memo, MapSet.new())
      memo
    end)
  end

  defp depth(id, sensory, memo, visiting) do
    cond do
      Map.has_key?(memo, id) -> {Map.fetch!(memo, id), memo}
      MapSet.member?(visiting, id) -> {0, memo}
      true ->
        node = Map.fetch!(sensory.nodes, id)
        {values, memo} = Enum.map_reduce(node.support, memo, fn member, acc ->
          if Map.fetch!(sensory.nodes, member).kind == :generated do
            depth(member, sensory, acc, MapSet.put(visiting, id))
          else
            {0, acc}
          end
        end)
        value = 1 + Enum.max(values, fn -> 0 end)
        {value, Map.put(memo, id, value)}
    end
  end

  defp collapsed_depth(sensory) do
    sensory.generated
    |> Enum.map(&collapsed_node_depth(&1, sensory, MapSet.new()))
    |> Enum.max(fn -> 0 end)
  end

  defp collapsed_node_depth(id, sensory, visiting) do
    if MapSet.member?(visiting, id) do
      0
    else
      node = Map.fetch!(sensory.nodes, id)
      children = Enum.filter(node.support, fn member ->
        Map.fetch!(sensory.nodes, member).kind == :generated
      end)

      child_depth = children
        |> Enum.map(&collapsed_node_depth(&1, sensory, MapSet.put(visiting, id)))
        |> Enum.max(fn -> 0 end)

      if length(children) == 1, do: child_depth, else: 1 + child_depth
    end
  end

  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
