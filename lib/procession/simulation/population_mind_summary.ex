defmodule Procession.Simulation.PopulationMindSummary do
  @moduledoc """
  Bounded coarse representation of unanchored developmental minds.

  The summary retains a limited set of causally distinct exemplar snapshots rather
  than one averaged mind or one snapshot per individual. Each cohort records its
  population weight and scalar variation. Refinement deterministically samples
  cohorts and perturbs only numeric strengths, preserving each exemplar's valid
  relational structure while producing compatible non-identical minds.
  """

  alias Procession.Simulation.DevelopmentalMindSnapshot

  @version 1

  def build(entries, opts \\ []) when is_list(entries) do
    limit = max(1, Keyword.get(opts, :population_mind_cohort_limit, 8))

    samples =
      entries
      |> Enum.with_index()
      |> Enum.map(fn
        {{id, snapshot}, index} -> %{id: id, index: index, snapshot: snapshot, vector: vector(snapshot)}
        {snapshot, index} -> %{id: {:anonymous, index}, index: index, snapshot: snapshot, vector: vector(snapshot)}
      end)

    cohorts =
      samples
      |> seed_cohorts(limit)
      |> assign_samples(samples)
      |> Enum.map(&finalize_cohort/1)

    %{
      version: @version,
      population: length(samples),
      cohorts: cohorts,
      metrics: %{
        cohort_count: length(cohorts),
        exemplar_cost: Enum.sum(Enum.map(cohorts, &DevelopmentalMindSnapshot.cost(&1.exemplar)))
      }
    }
  end

  def refine(%{version: @version, population: population, cohorts: cohorts}, ids, seed, _opts \\ [])
      when is_list(ids) and is_integer(seed) do
    count = min(length(ids), population)
    selected_ids = Enum.take(ids, count)
    total_weight = max(Enum.sum(Enum.map(cohorts, & &1.count)), 1)

    selected_ids
    |> Enum.with_index(1)
    |> Map.new(fn {id, index} ->
      ticket = rem(:erlang.phash2({seed, id, index, :cohort}), total_weight)
      cohort = weighted_pick(cohorts, ticket)
      factor = variation_factor(cohort, seed, id, index)
      {id, vary_snapshot(cohort.exemplar, factor)}
    end)
  end

  def refine(%{version: version}, _ids, _seed, _opts),
    do: raise(ArgumentError, "unsupported population mind summary version #{inspect(version)}")

  def refine(_summary, _ids, _seed, _opts),
    do: raise(ArgumentError, "invalid population mind summary")

  def cost(%{cohorts: cohorts}) do
    Enum.sum(Enum.map(cohorts, &(DevelopmentalMindSnapshot.cost(&1.exemplar) + 8)))
  end

  defp seed_cohorts([], _limit), do: []
  defp seed_cohorts([sample], _limit), do: [%{exemplar: sample, members: []}]

  defp seed_cohorts(samples, limit) do
    first = Enum.max_by(samples, &vector_mass(&1.vector))
    count = min(limit, length(samples))

    Enum.reduce(2..count, [%{exemplar: first, members: []}], fn _, cohorts ->
      candidate =
        samples
        |> Enum.reject(fn sample -> Enum.any?(cohorts, &(&1.exemplar.index == sample.index)) end)
        |> Enum.max_by(fn sample ->
          cohorts
          |> Enum.map(&distance(sample.vector, &1.exemplar.vector))
          |> Enum.min(fn -> 0.0 end)
        end)

      [%{exemplar: candidate, members: []} | cohorts]
    end)
    |> Enum.reverse()
  end

  defp assign_samples([], _samples), do: []

  defp assign_samples(cohorts, samples) do
    Enum.reduce(samples, cohorts, fn sample, current ->
      {cohort, index} =
        current
        |> Enum.with_index()
        |> Enum.min_by(fn {candidate, _index} -> distance(sample.vector, candidate.exemplar.vector) end)

      _ = cohort
      List.update_at(current, index, fn candidate -> %{candidate | members: [sample | candidate.members]} end)
    end)
  end

  defp finalize_cohort(%{exemplar: exemplar, members: members}) do
    vectors = Enum.map(members, & &1.vector)
    mean = mean_vector(vectors)
    variance = mean(Enum.map(vectors, &:math.pow(distance(&1, mean), 2)))

    %{exemplar: exemplar.snapshot, count: length(members), mean: mean, variance: variance}
  end

  defp vector(snapshot) do
    loop = DevelopmentalMindSnapshot.restore(snapshot)
    sensory = loop.field.sensory

    %{
      generated: MapSet.size(sensory.generated) * 1.0,
      edge_mass: sum_abs(sensory.edges),
      output_mass: sum_abs(loop.field.output_edges),
      imprint_mass: Enum.sum(Map.values(loop.field.salience.imprints)),
      exposure_mass: Enum.sum(Map.values(loop.field.salience.exposure)),
      active_mass: Enum.sum(Map.values(sensory.activity)),
      cycles: loop.cycles * 0.001
    }
  end

  defp vector_mass(vector), do: vector |> Map.values() |> Enum.sum()

  defp distance(left, right) do
    keys = Map.keys(left) |> Enum.concat(Map.keys(right)) |> Enum.uniq()

    keys
    |> Enum.map(fn key -> :math.pow(Map.get(left, key, 0.0) - Map.get(right, key, 0.0), 2) end)
    |> Enum.sum()
    |> :math.sqrt()
  end

  defp mean_vector([]), do: %{}

  defp mean_vector(vectors) do
    keys = vectors |> Enum.flat_map(&Map.keys/1) |> Enum.uniq()
    Map.new(keys, fn key -> {key, mean(Enum.map(vectors, &Map.get(&1, key, 0.0)))} end)
  end

  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp sum_abs(map), do: map |> Map.values() |> Enum.map(&abs/1) |> Enum.sum()

  defp weighted_pick([cohort | rest], ticket) do
    if ticket < cohort.count, do: cohort, else: weighted_pick(rest, ticket - cohort.count)
  end

  defp weighted_pick([], _ticket), do: raise(ArgumentError, "population mind summary has no weighted cohort")

  defp variation_factor(cohort, seed, id, index) do
    spread = min(:math.sqrt(max(cohort.variance, 0.0)) * 0.02, 0.20)
    unit = :erlang.phash2({seed, id, index, :mind_variation}, 10_001) / 10_000
    1.0 + (unit * 2.0 - 1.0) * spread
  end

  defp vary_snapshot(snapshot, factor) do
    loop = DevelopmentalMindSnapshot.restore(snapshot)
    sensory = loop.field.sensory

    sensory = %{
      sensory
      | edges: scale_map(sensory.edges, factor, 0.0, 10.0),
        activity: scale_map(sensory.activity, factor, 0.0, 10.0)
    }

    salience = %{
      loop.field.salience
      | exposure: scale_map(loop.field.salience.exposure, factor, 0.0, 1.0e9),
        imprints: scale_map(loop.field.salience.imprints, factor, 0.0, 1.0e9),
        last_metrics: %{}
    }

    field = %{
      loop.field
      | sensory: sensory,
        salience: salience,
        output_edges: scale_map(loop.field.output_edges, factor, 0.0, 3.0),
        previous_activity: scale_map(loop.field.previous_activity, factor, 0.0, 10.0)
    }

    %{snapshot | loop: %{loop | field: field, pending_output: nil}}
  end

  defp scale_map(map, factor, minimum, maximum) do
    Map.new(map, fn {key, value} -> {key, clamp(value * factor, minimum, maximum)} end)
  end

  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end