defmodule Procession.Simulation.DevelopmentalOriginExperiment do
  @moduledoc "Compares history sensitivity with modest rule sensitivity for generated field structure."

  alias Procession.Simulation.DevelopmentalField

  @base_opts [micro_nodes: 64, input_width: 3, consolidation_threshold: 4, coherence_threshold: 0.06, reuse_threshold: 0.50, edge_gain: 0.025, edge_retention: 0.9995, activity_retention: 0.72]

  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 720)
    seed = Keyword.get(opts, :seed, 1)
    actual = stream(ticks, seed)

    histories = [
      actual: actual,
      time_shuffled: deterministic_shuffle(actual, seed + 11),
      cooccurrence_shuffled: shuffle_channels(actual),
      outcome_decoupled: decouple_outcomes(actual)
    ]

    rules = [
      base: @base_opts,
      stricter: Keyword.merge(@base_opts, consolidation_threshold: 6, coherence_threshold: 0.09),
      looser: Keyword.merge(@base_opts, consolidation_threshold: 3, coherence_threshold: 0.04),
      faster_decay: Keyword.merge(@base_opts, edge_retention: 0.995, activity_retention: 0.62)
    ]

    history_runs = Map.new(histories, fn {name, inputs} -> {name, execute(inputs, @base_opts)} end)
    rule_runs = Map.new(rules, fn {name, field_opts} -> {name, execute(actual, field_opts)} end)
    baseline = history_runs.actual

    %{
      history_runs: history_runs,
      rule_runs: rule_runs,
      history_similarity: compare_group(baseline, history_runs),
      rule_similarity: compare_group(baseline, rule_runs)
    }
  end

  def report(result) do
    sections = [
      "Developmental origin factorial",
      "\nHistory variants",
      summarize_group(result.history_runs, result.history_similarity),
      "\nRule variants",
      summarize_group(result.rule_runs, result.rule_similarity),
      "\nInterpretation aid",
      "history sensitivity = structure changes when experience organization changes",
      "rule robustness = recognizable structure remains under modest mechanism changes",
      "outcome quality is intentionally not scored"
    ]

    Enum.join(sections, "\n")
  end

  defp execute(inputs, field_opts) do
    field = DevelopmentalField.run(inputs, field_opts)
    nodes = DevelopmentalField.generated_nodes(field)

    %{
      field: field,
      nodes: nodes,
      generated: length(nodes),
      edge_count: map_size(field.edges),
      edge_mass: DevelopmentalField.edge_mass(field.edges),
      mean_formation_coherence: mean(Enum.map(nodes, & &1.formation_coherence)),
      mean_formed_tick: mean(Enum.map(nodes, & &1.formed_tick)),
      mean_reuse: mean(Enum.map(nodes, & &1.reuse))
    }
  end

  defp compare_group(baseline, runs) do
    Map.new(runs, fn {name, run} ->
      {name, %{
        support_similarity: support_similarity(baseline.nodes, run.nodes),
        edge_similarity: edge_similarity(baseline.field.edges, run.field.edges),
        node_count_ratio: ratio(run.generated, baseline.generated)
      }}
    end)
  end

  defp summarize_group(runs, similarities) do
    runs
    |> Enum.sort_by(fn {name, _run} -> Atom.to_string(name) end)
    |> Enum.map_join("\n", fn {name, run} ->
      sim = similarities[name]
      "#{name}: generated=#{run.generated} edges=#{run.edge_count} edge_mass=#{fmt(run.edge_mass)} " <>
        "formation_coherence=#{fmt(run.mean_formation_coherence)} formed_tick=#{fmt(run.mean_formed_tick)} " <>
        "reuse=#{fmt(run.mean_reuse)} support_similarity=#{fmt(sim.support_similarity)} " <>
        "edge_similarity=#{fmt(sim.edge_similarity)} node_ratio=#{fmt(sim.node_count_ratio)}"
    end)
  end

  defp support_similarity([], []), do: 1.0
  defp support_similarity([], _), do: 0.0
  defp support_similarity(_, []), do: 0.0

  defp support_similarity(left, right) do
    left
    |> Enum.map(fn node ->
      right
      |> Enum.map(fn candidate -> jaccard(node.support, candidate.support) end)
      |> Enum.max(fn -> 0.0 end)
    end)
    |> mean()
  end

  defp edge_similarity(left, right) do
    left_keys = Map.keys(left) |> MapSet.new()
    right_keys = Map.keys(right) |> MapSet.new()
    jaccard(left_keys, right_keys)
  end

  defp jaccard(left, right) do
    union = MapSet.union(left, right) |> MapSet.size()
    if union == 0, do: 1.0, else: (MapSet.intersection(left, right) |> MapSet.size()) / union
  end

  defp stream(ticks, seed) do
    {inputs, _state} = Enum.map_reduce(1..ticks, %{capacity: 0.72, temperature: 0.58}, fn tick, state ->
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

  defp deterministic_shuffle(inputs, seed) do
    Enum.sort_by(inputs, fn input -> :erlang.phash2({seed, input}) end)
  end

  defp shuffle_channels(inputs) do
    rows = Enum.map(inputs, fn {:features, features} -> features end)
    count = length(rows)
    channels = rows |> List.first() |> length()

    for row_index <- 0..(count - 1) do
      features = for channel <- 0..(channels - 1) do
        source = rem(row_index + (channel + 1) * 37, count)
        rows |> Enum.at(source) |> Enum.at(channel)
      end
      {:features, features}
    end
  end

  defp decouple_outcomes(inputs) do
    contact = Enum.map(inputs, fn {:features, features} -> Enum.find(features, &match?({:contact_channel, _}, &1)) end)
    proximity = Enum.map(inputs, fn {:features, features} -> Enum.find(features, &match?({:sensory_channel, :caregiver_proximity, _}, &1)) end)
    count = length(inputs)

    inputs
    |> Enum.with_index()
    |> Enum.map(fn {{:features, features}, index} ->
      shifted_contact = Enum.at(contact, rem(index + 19, count))
      shifted_proximity = Enum.at(proximity, rem(index + 23, count))
      kept = Enum.reject(features, fn feature -> match?({:contact_channel, _}, feature) or match?({:sensory_channel, :caregiver_proximity, _}, feature) end)
      {:features, kept ++ [shifted_contact, shifted_proximity]}
    end)
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
  defp ratio(_value, 0), do: 0.0
  defp ratio(value, baseline), do: value / baseline
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
