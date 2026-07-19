defmodule Procession.Simulation.DevelopmentalTemporalProbe do
  @moduledoc """
  Probes whether the existing developmental field develops order-sensitive structure
  without adding temporal traces, directed learning, or authored sequence nodes.

  Every paired history preserves the same feature snapshots and frequencies. Only
  their order changes. Results therefore describe temporal sensitivity already
  available in the current mechanism rather than a newly supplied temporal field.
  """

  alias Procession.Simulation.DevelopmentalField

  @field_opts [
    micro_nodes: 64,
    input_width: 3,
    consolidation_threshold: 4,
    coherence_threshold: 0.06,
    reuse_threshold: 0.50,
    edge_gain: 0.025,
    edge_retention: 0.9995,
    activity_retention: 0.72
  ]

  @horizons [720, 2_880, 11_520]

  def run(opts \\ []) do
    seed = Keyword.get(opts, :seed, 1)
    horizons = Keyword.get(opts, :horizons, @horizons)

    horizon_results =
      Map.new(horizons, fn ticks ->
        histories = histories(ticks, seed)
        runs = Map.new(histories, fn {name, inputs} -> {name, execute(inputs)} end)
        {ticks, summarize_horizon(runs)}
      end)

    staged = staged_probe(Keyword.get(opts, :stage_cycles, 240), seed)

    %{horizons: horizon_results, staged: staged}
  end

  def report(result) do
    horizon_lines =
      result.horizons
      |> Enum.sort_by(fn {ticks, _} -> ticks end)
      |> Enum.flat_map(fn {ticks, horizon} ->
        [
          "ticks=#{ticks} baseline_nodes=#{horizon.baseline.generated} baseline_edges=#{horizon.baseline.edge_count}",
          comparison_line(:reversed, horizon.reversed),
          comparison_line(:rotated, horizon.rotated),
          comparison_line(:block_reversed, horizon.block_reversed)
        ]
      end)

    staged = result.staged

    staged_lines = [
      "staged forward_then_reverse: nodes=#{staged.forward_then_reverse.generated} edges=#{staged.forward_then_reverse.edge_count}",
      "staged reverse_then_forward: nodes=#{staged.reverse_then_forward.generated} edges=#{staged.reverse_then_forward.edge_count}",
      "staged similarity: support=#{fmt(staged.similarity.support_similarity)} edge_set=#{fmt(staged.similarity.edge_similarity)} edge_weight=#{fmt(staged.similarity.edge_weight_similarity)} generated_relations=#{staged.similarity.generated_relations}"
    ]

    Enum.join(["Extended temporal emergence probe" | horizon_lines ++ staged_lines], "\n")
  end

  defp histories(ticks, seed) do
    baseline = stream(ticks, seed)
    block_size = 48

    [
      baseline: baseline,
      reversed: Enum.reverse(baseline),
      rotated: rotate(baseline, div(length(baseline), 3)),
      block_reversed: reverse_blocks(baseline, block_size)
    ]
  end

  defp summarize_horizon(runs) do
    baseline = runs.baseline

    %{
      baseline: public_summary(baseline),
      reversed: compare(baseline, runs.reversed),
      rotated: compare(baseline, runs.rotated),
      block_reversed: compare(baseline, runs.block_reversed)
    }
  end

  defp staged_probe(cycles, seed) do
    forward = sequence_cycle(:forward, seed)
    reverse = sequence_cycle(:reverse, seed)

    forward_then_reverse = List.duplicate(forward, cycles) |> List.flatten()
    reverse_then_forward = List.duplicate(reverse, cycles) |> List.flatten()

    first = execute(forward_then_reverse ++ reverse_then_forward)
    second = execute(reverse_then_forward ++ forward_then_reverse)

    %{
      forward_then_reverse: public_summary(first),
      reverse_then_forward: public_summary(second),
      similarity: compare(first, second)
    }
  end

  defp sequence_cycle(direction, seed) do
    a = {:features, [{:probe, :a}, {:context, rem(seed, 3)}, {:body, :steady}]}
    b = {:features, [{:probe, :b}, {:context, rem(seed + 1, 3)}, {:body, :steady}]}
    c = {:features, [{:probe, :c}, {:context, rem(seed + 2, 3)}, {:body, :steady}]}
    gap = {:features, [{:probe, :gap}, {:context, :neutral}, {:body, :steady}]}

    case direction do
      :forward -> [a, gap, b, gap, c, gap]
      :reverse -> [c, gap, b, gap, a, gap]
    end
  end

  defp execute(inputs) do
    field = DevelopmentalField.run(inputs, @field_opts)
    nodes = DevelopmentalField.generated_nodes(field)

    %{
      field: field,
      nodes: nodes,
      generated: length(nodes),
      edge_count: map_size(field.edges),
      edge_mass: DevelopmentalField.edge_mass(field.edges),
      generated_relations: generated_relation_count(field)
    }
  end

  defp public_summary(run) do
    Map.take(run, [:generated, :edge_count, :edge_mass, :generated_relations])
  end

  defp compare(left, right) do
    %{
      generated: right.generated,
      edge_count: right.edge_count,
      support_similarity: support_similarity(left.nodes, right.nodes),
      edge_similarity: edge_set_similarity(left.field.edges, right.field.edges),
      edge_weight_similarity: edge_weight_similarity(left.field.edges, right.field.edges),
      generated_relations: right.generated_relations
    }
  end

  defp generated_relation_count(run_or_field) do
    field = Map.get(run_or_field, :field, run_or_field)

    Enum.count(field.edges, fn {{left, right}, _weight} ->
      left >= field.micro_nodes and right >= field.micro_nodes
    end)
  end

  defp support_similarity([], []), do: 1.0
  defp support_similarity([], _), do: 0.0
  defp support_similarity(_, []), do: 0.0

  defp support_similarity(left, right) do
    left
    |> Enum.map(fn node ->
      right
      |> Enum.map(fn other -> jaccard(node.support, other.support) end)
      |> Enum.max(fn -> 0.0 end)
    end)
    |> mean()
  end

  defp edge_set_similarity(left, right) do
    jaccard(Map.keys(left) |> MapSet.new(), Map.keys(right) |> MapSet.new())
  end

  defp edge_weight_similarity(left, right) do
    keys = Map.keys(left) |> MapSet.new() |> MapSet.union(Map.keys(right) |> MapSet.new())

    if MapSet.size(keys) == 0 do
      1.0
    else
      difference =
        Enum.reduce(keys, 0.0, fn key, total ->
          total + abs(Map.get(left, key, 0.0) - Map.get(right, key, 0.0))
        end)

      scale =
        Enum.reduce(keys, 0.0, fn key, total ->
          total + max(Map.get(left, key, 0.0), Map.get(right, key, 0.0))
        end)

      if scale == 0.0, do: 1.0, else: max(0.0, 1.0 - difference / scale)
    end
  end

  defp jaccard(left, right) do
    union = MapSet.union(left, right) |> MapSet.size()
    if union == 0, do: 1.0, else: (MapSet.intersection(left, right) |> MapSet.size()) / union
  end

  defp rotate(values, amount) do
    {left, right} = Enum.split(values, rem(amount, max(length(values), 1)))
    right ++ left
  end

  defp reverse_blocks(values, size) do
    values
    |> Enum.chunk_every(size)
    |> Enum.flat_map(&Enum.reverse/1)
  end

  defp stream(ticks, seed) do
    {inputs, _state} =
      Enum.map_reduce(1..ticks, %{capacity: 0.72, temperature: 0.58}, fn tick, state ->
        contact? = rem(tick, 48) in 0..5
        cue = caregiver_cue(tick)
        motor = motor_output(state, tick, seed)
        capacity = clamp(state.capacity - 0.010 + if(contact?, do: 0.22, else: 0.0))
        temperature = clamp(state.temperature - 0.012 + if(contact?, do: 0.25, else: 0.0))

        features = [
          {:body_channel, :capacity, bucket(capacity)},
          {:body_channel, :temperature, bucket(temperature)},
          {:sensory_channel, :caregiver_proximity, bucket(cue)},
          {:motor_channel, motor},
          {:change_channel, :capacity, trend(capacity - state.capacity)},
          {:change_channel, :temperature, trend(temperature - state.temperature)},
          {:change_channel, :caregiver_proximity, trend(cue - caregiver_cue(tick - 1))},
          {:contact_channel, contact?}
        ]

        {{:features, features}, %{capacity: capacity, temperature: temperature}}
      end)

    inputs
  end

  defp caregiver_cue(tick) do
    phase = rem(tick, 48)

    cond do
      phase <= 5 -> 1.0
      phase <= 18 -> 1.0 - (phase - 5) / 18
      phase <= 32 -> 0.25
      true -> 0.25 + (phase - 32) / 16 * 0.75
    end
  end

  defp motor_output(state, tick, seed) do
    value = :erlang.phash2({seed, tick, bucket(state.capacity), bucket(state.temperature)}, 100)

    cond do
      value < 24 -> :negative
      value < 48 -> :positive
      true -> :still
    end
  end

  defp bucket(value), do: value |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp trend(delta) when delta > 0.015, do: :rising
  defp trend(delta) when delta < -0.015, do: :falling
  defp trend(_delta), do: :stable
  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)

  defp comparison_line(name, comparison) do
    "#{name}: generated=#{comparison.generated} edges=#{comparison.edge_count} " <>
      "support=#{fmt(comparison.support_similarity)} edge_set=#{fmt(comparison.edge_similarity)} " <>
      "edge_weight=#{fmt(comparison.edge_weight_similarity)} generated_relations=#{comparison.generated_relations}"
  end
end
