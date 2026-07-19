defmodule Procession.Simulation.DevelopmentalPopulationExperiment do
  @moduledoc """
  Compares cloned and minimally varied developmental fields.

  The observer keeps representational convergence separate from consolidation
  coverage. Equal node counts are therefore not treated as equal development,
  and a large memory repertoire is checked against the recurring signature space
  that was available to be consolidated.
  """

  alias Procession.Simulation.DevelopmentalField

  @field_opts [
    micro_nodes: 64,
    input_width: 3,
    consolidation_threshold: 4,
    coherence_threshold: 0.06,
    reuse_threshold: 0.50,
    edge_retention: 0.9995,
    activity_retention: 0.72,
    plasticity_fanout: 6,
    plasticity_budget: 0.08
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 8)
    ticks = Keyword.get(opts, :ticks, 2_880)
    seed = Keyword.get(opts, :seed, 1)

    baseline_history = stream(ticks, seed, 0)

    clone_runs =
      Enum.map(1..population, fn _ -> execute(baseline_history, @field_opts) end)

    salted_runs =
      Enum.map(1..population, fn entity ->
        execute(baseline_history, Keyword.put(@field_opts, :encoding_salt, {:entity, entity}))
      end)

    varied_runs =
      Enum.map(1..population, fn entity ->
        execute(stream(ticks, seed, entity), @field_opts)
      end)

    salted_varied_runs =
      Enum.map(1..population, fn entity ->
        execute(
          stream(ticks, seed, entity),
          Keyword.put(@field_opts, :encoding_salt, {:entity, entity})
        )
      end)

    %{
      ticks: ticks,
      population: population,
      clones: summarize(clone_runs, :shared),
      salted: summarize(salted_runs, :distinct),
      varied_history: summarize(varied_runs, :shared),
      salted_varied: summarize(salted_varied_runs, :distinct)
    }
  end

  def report(result) do
    [
      "Developmental population divergence",
      "ticks=#{result.ticks} population=#{result.population}",
      group_line(:clones, result.clones),
      group_line(:salted, result.salted),
      group_line(:varied_history, result.varied_history),
      group_line(:salted_varied, result.salted_varied)
    ]
    |> Enum.join("\n")
  end

  defp execute(inputs, opts) do
    field = DevelopmentalField.run(inputs, opts)
    nodes = DevelopmentalField.generated_nodes(field)
    threshold = Keyword.fetch!(opts, :consolidation_threshold)

    eligible_signatures = Enum.count(field.recurrence, fn {_signature, count} -> count >= threshold end)
    distinct_signatures = map_size(field.recurrence)

    %{
      field: field,
      nodes: nodes,
      generated: length(nodes),
      eligible_signatures: eligible_signatures,
      distinct_signatures: distinct_signatures,
      eligible_coverage: ratio(length(nodes), eligible_signatures),
      distinct_coverage: ratio(length(nodes), distinct_signatures),
      profile: profile(field, nodes)
    }
  end

  defp summarize(runs, encoding_mode) do
    counts = Enum.map(runs, & &1.generated)
    eligible_coverage = Enum.map(runs, & &1.eligible_coverage)
    distinct_coverage = Enum.map(runs, & &1.distinct_coverage)

    %{
      node_min: Enum.min(counts),
      node_max: Enum.max(counts),
      node_mean: mean(counts),
      eligible_coverage_mean: mean(eligible_coverage),
      distinct_coverage_mean: mean(distinct_coverage),
      support_similarity: if(encoding_mode == :shared, do: pair_mean(runs, &support_similarity/2), else: nil),
      edge_similarity: if(encoding_mode == :shared, do: pair_mean(runs, &edge_similarity/2), else: nil),
      profile_similarity: pair_mean(runs, &profile_similarity/2)
    }
  end

  defp profile(field, nodes) do
    support_sizes = nodes |> Enum.map(&MapSet.size(&1.support)) |> Enum.sort()
    hierarchy = nodes |> Enum.map(&generated_support_count(&1, field.micro_nodes)) |> Enum.sort()
    formed = nodes |> Enum.map(& &1.formed_tick) |> Enum.sort()
    possible = max(length(nodes) * max(length(nodes) - 1, 0), 1)

    %{
      support_sizes: support_sizes,
      hierarchy: hierarchy,
      formed: formed,
      generated_edge_density: generated_edge_count(field) / possible
    }
  end

  defp generated_support_count(node, micro_nodes) do
    Enum.count(node.support, &(&1 >= micro_nodes))
  end

  defp generated_edge_count(field) do
    Enum.count(field.edges, fn {{source, target}, _weight} ->
      source >= field.micro_nodes and target >= field.micro_nodes
    end)
  end

  defp support_similarity(left, right) do
    directional_support_similarity(left.nodes, right.nodes)
  end

  defp directional_support_similarity([], []), do: 1.0
  defp directional_support_similarity([], _), do: 0.0
  defp directional_support_similarity(_, []), do: 0.0

  defp directional_support_similarity(left, right) do
    left
    |> Enum.map(fn node ->
      right
      |> Enum.map(fn other -> jaccard(node.support, other.support) end)
      |> Enum.max(fn -> 0.0 end)
    end)
    |> mean()
  end

  defp edge_similarity(left, right) do
    jaccard(Map.keys(left.field.edges) |> MapSet.new(), Map.keys(right.field.edges) |> MapSet.new())
  end

  defp profile_similarity(left, right) do
    components = [
      sequence_similarity(left.profile.support_sizes, right.profile.support_sizes),
      sequence_similarity(left.profile.hierarchy, right.profile.hierarchy),
      sequence_similarity(left.profile.formed, right.profile.formed),
      1.0 - abs(left.profile.generated_edge_density - right.profile.generated_edge_density)
    ]

    mean(components)
  end

  defp sequence_similarity(left, right) do
    length_penalty = abs(length(left) - length(right)) / max(max(length(left), length(right)), 1)
    paired = Enum.zip(left, right)

    value_similarity =
      if paired == [] do
        if left == right, do: 1.0, else: 0.0
      else
        scale = max(Enum.max(left ++ right, fn -> 1 end), 1)
        paired |> Enum.map(fn {a, b} -> 1.0 - abs(a - b) / scale end) |> mean()
      end

    max(0.0, value_similarity - length_penalty)
  end

  defp pair_mean(runs, comparer) do
    pairs = for {left, index} <- Enum.with_index(runs), right <- Enum.drop(runs, index + 1), do: comparer.(left, right)
    mean(pairs)
  end

  defp stream(ticks, seed, entity_variation) do
    {inputs, _state} =
      Enum.map_reduce(1..ticks, %{capacity: 0.72, temperature: 0.58}, fn tick, state ->
        phase_shift = rem(entity_variation * 7, 48)
        local_tick = tick + phase_shift
        contact? = rem(local_tick, 48) in 0..5
        cue = caregiver_cue(local_tick)
        motor = motor_output(state, tick, seed + entity_variation)

        capacity = clamp(state.capacity - 0.010 + if(contact?, do: 0.22, else: 0.0))
        temperature = clamp(state.temperature - 0.012 + if(contact?, do: 0.25, else: 0.0))

        features = [
          {:body_channel, :capacity, bucket(capacity)},
          {:body_channel, :temperature, bucket(temperature)},
          {:sensory_channel, :caregiver_proximity, bucket(cue)},
          {:motor_channel, motor},
          {:change_channel, :capacity, trend(capacity - state.capacity)},
          {:change_channel, :temperature, trend(temperature - state.temperature)},
          {:change_channel, :caregiver_proximity, trend(cue - caregiver_cue(local_tick - 1))},
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

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(nil), do: "n/a"
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)

  defp jaccard(left, right) do
    union = MapSet.union(left, right) |> MapSet.size()
    if union == 0, do: 1.0, else: MapSet.intersection(left, right) |> MapSet.size() / union
  end

  defp group_line(name, group) do
    "#{name}: nodes=#{fmt(group.node_mean)} range=#{group.node_min}..#{group.node_max} " <>
      "eligible_coverage=#{fmt(group.eligible_coverage_mean)} distinct_coverage=#{fmt(group.distinct_coverage_mean)} " <>
      "support=#{fmt(group.support_similarity)} edges=#{fmt(group.edge_similarity)} profile=#{fmt(group.profile_similarity)}"
  end
end