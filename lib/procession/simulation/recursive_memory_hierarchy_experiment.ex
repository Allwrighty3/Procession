defmodule Procession.Simulation.RecursiveMemoryHierarchyExperiment do
  @moduledoc "Stages local memory formation before testing higher-order consolidation."

  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  @phases [
    {:depart, :motor_a, [location: :home, carrying: false, pressure: :hunger]},
    {:resource, :motor_b, [location: :resource, carrying: false, contact: true]},
    {:return, :motor_c, [location: :away, carrying: true, pressure: :hunger]},
    {:consume, :motor_d, [location: :home, carrying: true, contact: true]}
  ]

  @base [micro_nodes: 96, input_width: 6, activity_retention: 0.80,
    edge_retention: 0.9995, output_edge_retention: 0.9995,
    consolidation_threshold: 4, minimum_compression_gain: 0.0,
    coherence_threshold: 0.015, compression_node_threshold: 0.12,
    compression_coverage_threshold: 0.42, plasticity_threshold: 0.12,
    output_source_threshold: 0.08, output_plasticity_budget: 0.12,
    output_learning_scale: 0.30]

  def run(opts \\ []) do
    local_repetitions = Keyword.get(opts, :local_repetitions, 40)
    routine_repetitions = Keyword.get(opts, :routine_repetitions, 180)
    seed = Keyword.get(opts, :seed, 1)

    rows = Enum.map([:legacy, :quality], fn condition ->
      field = Field.new(field_opts(condition, seed))

      local = Enum.reduce(@phases, field, fn {phase, output, features}, acc ->
        Enum.reduce(1..local_repetitions, acc, fn repetition, state ->
          state
          |> Field.sense(features(phase, features, {:local, repetition}), field_opts(condition, seed))
          |> Field.record_output(output, 1.0, field_opts(condition, seed))
        end)
      end)

      final = Enum.reduce(1..routine_repetitions, local, fn episode, acc ->
        Enum.reduce(@phases, acc, fn {phase, output, phase_features}, state ->
          state
          |> Field.sense(features(phase, phase_features, {:routine, rem(episode, 3)}), field_opts(condition, seed))
          |> Field.record_output(output, 1.0, field_opts(condition, seed))
        end)
      end)

      Map.put(structure(final.sensory), :condition, condition)
    end)

    %{local_repetitions: local_repetitions, routine_repetitions: routine_repetitions, rows: rows}
  end

  def report(result) do
    lines = Enum.map(result.rows, fn row ->
      "#{row.condition}: generated=#{row.generated} recursive=#{row.recursive} " <>
        "max_depth=#{row.max_depth} collapsed_depth=#{row.collapsed_depth} " <>
        "branching=#{row.branching} single_child=#{row.single_child}"
    end)

    Enum.join(["Staged recursive hierarchy audit",
      "local=#{result.local_repetitions} routine=#{result.routine_repetitions}" | lines], "\n")
  end

  defp features(phase, features, variation) do
    [{:routine, :resource_cycle}, {:phase, phase}, {:variation, variation} |
      Enum.map(features, fn {key, value} -> {key, value} end)]
  end

  defp field_opts(:legacy, seed), do:
    [encoding_salt: {:hierarchy_quality, seed}, output_source_mode: :active,
     recursive_quality_gate: false] ++ @base

  defp field_opts(:quality, seed), do:
    [encoding_salt: {:hierarchy_quality, seed}, output_source_mode: :rising_residual,
     output_specificity_power: 0.5, recursive_quality_gate: true,
     recursive_min_residual_members: 2, recursive_ancestor_penalty: 1.0,
     minimum_incremental_compression_gain: 0.5] ++ @base

  defp structure(sensory) do
    depths = depths(sensory)
    child_counts = Enum.map(sensory.generated, fn id ->
      node = Map.fetch!(sensory.nodes, id)
      Enum.count(node.support, fn member -> Map.fetch!(sensory.nodes, member).kind == :generated end)
    end)

    %{generated: MapSet.size(sensory.generated),
      recursive: Enum.count(depths, fn {_id, depth} -> depth >= 2 end),
      max_depth: depths |> Map.values() |> Enum.max(fn -> 0 end),
      collapsed_depth: collapsed_depth(sensory),
      branching: Enum.count(child_counts, &(&1 >= 2)),
      single_child: Enum.count(child_counts, &(&1 == 1))}
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
        {children, memo} = Enum.map_reduce(node.support, memo, fn member, acc ->
          if Map.fetch!(sensory.nodes, member).kind == :generated,
            do: depth(member, sensory, acc, MapSet.put(visiting, id)), else: {0, acc}
        end)
        value = 1 + Enum.max(children, fn -> 0 end)
        {value, Map.put(memo, id, value)}
    end
  end

  defp collapsed_depth(sensory) do
    sensory.generated |> Enum.map(&collapsed(&1, sensory, MapSet.new())) |> Enum.max(fn -> 0 end)
  end

  defp collapsed(id, sensory, visiting) do
    if MapSet.member?(visiting, id), do: 0, else: begin_collapsed(id, sensory, visiting)
  end

  defp begin_collapsed(id, sensory, visiting) do
    node = Map.fetch!(sensory.nodes, id)
    children = Enum.filter(node.support, fn member -> Map.fetch!(sensory.nodes, member).kind == :generated end)
    child_depth = children |> Enum.map(&collapsed(&1, sensory, MapSet.put(visiting, id))) |> Enum.max(fn -> 0 end)
    if length(children) == 1, do: child_depth, else: 1 + child_depth
  end
end
