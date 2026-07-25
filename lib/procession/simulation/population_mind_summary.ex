defmodule Procession.Simulation.PopulationMindSummary do
  @moduledoc """
  Bounded population-level summaries for dormant developmental minds.

  Individual snapshots are grouped into causal cohorts. Each cohort retains one bounded
  prototype, its prevalence, and aggregate causal severity. Common cohorts and rare
  high-impact cohorts both compete for a fixed number of slots. Refinement selects a
  cohort deterministically and applies bounded variation without inventing new topology.
  """

  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop

  @version 1

  def capture(snapshots, total_population, opts \\ [])
      when is_list(snapshots) and is_integer(total_population) and total_population >= 0 do
    cohort_limit = max(Keyword.get(opts, :population_mind_cohort_limit, 8), 0)
    normalized = Enum.map(snapshots, &normalize_snapshot!/1)

    all_cohorts =
      normalized
      |> Enum.group_by(&signature/1)
      |> Enum.map(fn {signature, members} -> build_cohort(signature, members) end)

    cohorts = select_cohorts(all_cohorts, cohort_limit)

    %{
      version: @version,
      total_population: total_population,
      minded_population: length(normalized),
      cohorts: cohorts,
      omitted_cohorts: max(length(all_cohorts) - length(cohorts), 0)
    }
  end

  def instantiate(summary, seed, ordinal, opts \\ [])

  def instantiate(%{version: @version} = summary, seed, ordinal, opts)
      when is_integer(seed) and is_integer(ordinal) and ordinal > 0 do
    if receives_mind?(summary, seed, ordinal) and summary.cohorts != [] do
      cohort = choose_cohort(summary.cohorts, seed, ordinal)
      {:ok, vary_snapshot(cohort.prototype, seed, ordinal, opts)}
    else
      :none
    end
  end

  def instantiate(%{version: version}, _seed, _ordinal, _opts),
    do: {:error, {:unsupported_population_mind_summary, version}}

  def instantiate(_summary, _seed, _ordinal, _opts), do: {:error, :invalid_population_mind_summary}

  def cost(%{version: @version, cohorts: cohorts}) do
    Enum.reduce(cohorts, 5, fn cohort, total ->
      total + 4 + DevelopmentalMindSnapshot.cost(cohort.prototype)
    end)
  end

  def trace(%{version: @version} = summary) do
    %{
      total_population: summary.total_population,
      minded_population: summary.minded_population,
      cohort_count: length(summary.cohorts),
      represented_minds: Enum.sum(Enum.map(summary.cohorts, & &1.count)),
      omitted_cohorts: summary.omitted_cohorts,
      cost: cost(summary)
    }
  end

  defp normalize_snapshot!(snapshot) do
    case DevelopmentalMindSnapshot.restore(snapshot) do
      %DevelopmentalSensorimotorLoop{} -> snapshot
    end
  end

  defp build_cohort(signature, members) do
    prototype = Enum.max_by(members, &causal_mass/1)

    %{
      signature: signature,
      count: length(members),
      severity: Enum.max(Enum.map(members, &causal_mass/1), fn -> 0.0 end),
      prototype: prototype
    }
  end

  defp select_cohorts(_cohorts, limit) when limit <= 0, do: []

  defp select_cohorts(cohorts, limit) do
    common = Enum.sort_by(cohorts, fn cohort -> {-cohort.count, -cohort.severity, cohort.signature} end)
    severe = Enum.sort_by(cohorts, fn cohort -> {-cohort.severity, -cohort.count, cohort.signature} end)
    common_slots = div(limit + 1, 2)

    selected =
      (Enum.take(common, common_slots) ++ Enum.take(severe, limit - common_slots))
      |> Enum.uniq_by(& &1.signature)

    if length(selected) < min(limit, length(cohorts)) do
      remainder = Enum.reject(common, fn cohort -> Enum.any?(selected, &(&1.signature == cohort.signature)) end)
      Enum.take(selected ++ remainder, limit)
    else
      selected
    end
    |> Enum.sort_by(& &1.signature)
  end

  defp receives_mind?(%{total_population: total, minded_population: minded}, _seed, _ordinal)
       when total <= 0 or minded <= 0,
       do: false

  defp receives_mind?(%{total_population: total, minded_population: minded}, seed, ordinal) do
    threshold = min(minded / total, 1.0)
    :erlang.phash2({:population_mind_presence, seed, ordinal}, 1_000_000) / 1_000_000 < threshold
  end

  defp choose_cohort(cohorts, seed, ordinal) do
    total = Enum.sum(Enum.map(cohorts, & &1.count))
    target = rem(:erlang.phash2({:population_mind_cohort, seed, ordinal}), max(total, 1))

    Enum.reduce_while(cohorts, target, fn cohort, remaining ->
      if remaining < cohort.count, do: {:halt, cohort}, else: {:cont, remaining - cohort.count}
    end)
  end

  defp vary_snapshot(snapshot, seed, ordinal, opts) do
    scale = Keyword.get(opts, :population_mind_variation, 0.08) |> max(0.0) |> min(0.35)
    loop = DevelopmentalMindSnapshot.restore(snapshot)
    field = loop.field
    sensory = field.sensory

    varied = %{
      loop
      | field: %{
          field
          | sensory: %{
              sensory
              | edges: vary_weights(sensory.edges, seed, ordinal, :sensory, scale, 0.0, 10.0),
                activity: vary_weights(sensory.activity, seed, ordinal, :activity, scale, 0.0, 10.0),
                history: []
            },
            output_edges: vary_weights(field.output_edges, seed, ordinal, :output, scale, 0.0, 3.0),
            previous_activity: %{},
            salience: %{
              field.salience
              | imprints: vary_weights(field.salience.imprints, seed, ordinal, :imprint, scale, 0.0, 100.0),
                last_metrics: %{}
            }
        },
        pending_output: nil,
        last_outcome: nil
    }

    DevelopmentalMindSnapshot.capture(varied, opts)
  end

  defp vary_weights(weights, seed, ordinal, domain, scale, minimum, maximum) do
    Map.new(weights, fn {key, value} ->
      noise = (:erlang.phash2({domain, seed, ordinal, key}, 20_001) - 10_000) / 10_000
      varied = value * (1.0 + noise * scale)
      {key, varied |> max(minimum) |> min(maximum)}
    end)
  end

  defp signature(snapshot) do
    loop = DevelopmentalMindSnapshot.restore(snapshot)
    field = loop.field

    dominant_output =
      field.output_edges
      |> Enum.group_by(fn {{_source, output}, _weight} -> output end, fn {_edge, weight} -> weight end)
      |> Enum.map(fn {output, weights} -> {output, Enum.sum(weights)} end)
      |> Enum.max_by(fn {output, weight} -> {weight, output} end, fn -> {:none, 0.0} end)
      |> elem(0)

    imprint_bucket =
      field.salience.imprints
      |> Map.values()
      |> Enum.sum()
      |> Kernel.*(2.0)
      |> round()
      |> min(20)

    motif_fingerprints =
      field.sensory.generated
      |> Enum.map(fn id -> micro_support_fingerprint(id, field.sensory.nodes, MapSet.new()) end)
      |> Enum.sort()
      |> Enum.take(4)

    :erlang.phash2({field.sensory.micro_nodes, dominant_output, imprint_bucket, motif_fingerprints})
  end

  defp micro_support_fingerprint(id, nodes, seen) do
    if MapSet.member?(seen, id) do
      []
    else
      node = Map.fetch!(nodes, id)

      if node.kind == :micro do
        [id]
      else
        seen = MapSet.put(seen, id)

        node.support
        |> Enum.flat_map(&micro_support_fingerprint(&1, nodes, seen))
        |> Enum.uniq()
        |> Enum.sort()
      end
    end
  end

  defp causal_mass(snapshot) do
    loop = DevelopmentalMindSnapshot.restore(snapshot)
    field = loop.field

    Enum.sum(Map.values(field.sensory.activity)) +
      Enum.sum(Enum.map(field.sensory.edges, fn {_edge, weight} -> abs(weight) end)) * 0.2 +
      Enum.sum(Enum.map(field.output_edges, fn {_edge, weight} -> abs(weight) end)) +
      Enum.sum(Map.values(field.salience.imprints)) * 2.0
  end
end