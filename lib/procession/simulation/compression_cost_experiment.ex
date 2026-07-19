defmodule Procession.Simulation.CompressionCostExperiment do
  @moduledoc """
  Measures whether developmental compression pays for its own runtime and state cost.

  The comparison includes the whole field update path, not only the constant-time
  description-length arithmetic. BEAM reductions are reported alongside elapsed
  time because reductions are less sensitive to runner load.
  """

  alias Procession.Simulation.DevelopmentalField

  @base_opts [
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
    ticks = Keyword.get(opts, :ticks, 2_880)
    seed = Keyword.get(opts, :seed, 1)
    samples = Keyword.get(opts, :samples, 5)
    inputs = stream(ticks, seed)

    variants = [
      gain_gated: @base_opts,
      permissive_gain: Keyword.put(@base_opts, :minimum_compression_gain, -1.0e30),
      explanation_disabled:
        @base_opts
        |> Keyword.put(:minimum_compression_gain, -1.0e30)
        |> Keyword.put(:compression_coverage_threshold, 2.0)
    ]

    results =
      Map.new(variants, fn {name, field_opts} ->
        {name, measure(inputs, field_opts, samples)}
      end)

    %{ticks: ticks, samples: samples, variants: results, comparison: compare(results)}
  end

  def report(result) do
    lines =
      [:gain_gated, :permissive_gain, :explanation_disabled]
      |> Enum.map(fn name ->
        value = Map.fetch!(result.variants, name)

        "#{name}: median_us=#{value.median_us} median_reductions=#{value.median_reductions} " <>
          "generated=#{value.generated} edges=#{value.edges} state_words=#{value.state_words} " <>
          "avg_learning_field=#{format(value.avg_learning_field)}"
      end)

    comparison = result.comparison

    Enum.join(
      [
        "Compression computational cost",
        "ticks=#{result.ticks} samples=#{result.samples}",
        "gain_vs_permissive runtime_ratio=#{format(comparison.runtime_ratio)} " <>
          "reduction_ratio=#{format(comparison.reduction_ratio)} state_ratio=#{format(comparison.state_ratio)}"
        | lines
      ],
      "\n"
    )
  end

  defp measure(inputs, field_opts, samples) do
    runs = Enum.map(1..samples, fn _ -> measured_run(inputs, field_opts) end)
    representative = runs |> Enum.sort_by(& &1.reductions) |> Enum.at(div(samples, 2))

    %{
      median_us: runs |> Enum.map(& &1.elapsed_us) |> median(),
      median_reductions: runs |> Enum.map(& &1.reductions) |> median(),
      generated: representative.generated,
      edges: representative.edges,
      state_words: representative.state_words,
      avg_learning_field: representative.avg_learning_field
    }
  end

  defp measured_run(inputs, field_opts) do
    :erlang.garbage_collect()
    {before_reductions, _} = process_reductions()
    started = System.monotonic_time(:microsecond)
    field = DevelopmentalField.run(inputs, field_opts)
    elapsed_us = System.monotonic_time(:microsecond) - started
    {after_reductions, _} = process_reductions()

    %{
      elapsed_us: elapsed_us,
      reductions: after_reductions - before_reductions,
      generated: MapSet.size(field.generated),
      edges: map_size(field.edges),
      state_words: :erts_debug.size(field),
      avg_learning_field: average_learning_field(field.history)
    }
  end

  defp compare(results) do
    gated = Map.fetch!(results, :gain_gated)
    permissive = Map.fetch!(results, :permissive_gain)

    %{
      runtime_ratio: ratio(gated.median_us, permissive.median_us),
      reduction_ratio: ratio(gated.median_reductions, permissive.median_reductions),
      state_ratio: ratio(gated.state_words, permissive.state_words)
    }
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

  defp average_learning_field([]), do: 0.0

  defp average_learning_field(history) do
    history
    |> Enum.map(&Map.get(&1, :learning_field, Map.get(&1, :active_field, 0)))
    |> then(&(Enum.sum(&1) / length(&1)))
  end

  defp process_reductions do
    case Process.info(self(), :reductions) do
      {:reductions, value} -> {value, :ok}
      nil -> {0, :unavailable}
    end
  end

  defp median(values) do
    sorted = Enum.sort(values)
    Enum.at(sorted, div(length(sorted), 2))
  end

  defp ratio(_left, 0), do: 0.0
  defp ratio(left, right), do: left / right
  defp bucket(value), do: value |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp trend(delta) when delta > 0.015, do: :rising
  defp trend(delta) when delta < -0.015, do: :falling
  defp trend(_delta), do: :stable
  defp clamp(value), do: value |> max(0.0) |> min(1.0)
  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end