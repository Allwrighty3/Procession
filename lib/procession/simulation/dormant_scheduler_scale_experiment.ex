defmodule Procession.Simulation.DormantSchedulerScaleExperiment do
  @moduledoc """
  Measures bounded dormant scheduler selection cost and service fairness.

  This experiment deliberately does not restore or run developmental minds. It isolates
  the scheduling question: given a stable waiting population, how do population size,
  per-cycle budget, and cadence affect selection overhead, coverage, and opportunity
  distribution? Full dormant mind-cycle cost must be measured separately.
  """

  alias Procession.Simulation.DormantLocomotionBatch

  @default_populations [100, 1_000, 10_000]
  @default_budgets [8, 32, 128]
  @default_cadences [1, 4, 16]
  @default_ticks 256

  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    populations =
      normalize_positive_list(
        Keyword.get(opts, :populations, @default_populations),
        @default_populations
      )

    budgets =
      normalize_non_negative_list(Keyword.get(opts, :budgets, @default_budgets), @default_budgets)

    cadences =
      normalize_positive_list(Keyword.get(opts, :cadences, @default_cadences), @default_cadences)

    ticks = normalize_positive(Keyword.get(opts, :ticks, @default_ticks), @default_ticks)

    scenarios =
      for population <- populations,
          budget <- budgets,
          cadence <- cadences do
        measure(population, budget, cadence, ticks)
      end

    %{
      experiment: :dormant_scheduler_scale,
      scope: :scheduler_only,
      ticks: ticks,
      populations: populations,
      budgets: budgets,
      cadences: cadences,
      scenarios: scenarios
    }
  end

  defp measure(population, budget, cadence, ticks) do
    waiting = Enum.map(1..population, &identity/1)
    initial_counts = Map.new(waiting, &{&1, 0})

    {runtime_us, {counts, attempted, eligible_cycles}} =
      :timer.tc(fn ->
        Enum.reduce(1..ticks, {initial_counts, 0, 0}, fn tick, {counts, attempted, cycles} ->
          if rem(tick, cadence) == 0 do
            selected = DormantLocomotionBatch.rotate_take(waiting, tick, budget)

            updated_counts =
              Enum.reduce(selected, counts, fn identity_id, acc ->
                Map.update!(acc, identity_id, &(&1 + 1))
              end)

            {updated_counts, attempted + length(selected), cycles + 1}
          else
            {counts, attempted, cycles}
          end
        end)
      end)

    values = Map.values(counts)
    selected_population = Enum.count(values, &(&1 > 0))

    min_selected =
      if selected_population == 0 do
        0
      else
        values
        |> Enum.reject(&(&1 == 0))
        |> Enum.min()
      end

    max_selected = if values == [], do: 0, else: Enum.max(values)
    capacity = eligible_cycles * min(budget, population)

    %{
      population: population,
      budget: budget,
      cadence: cadence,
      eligible_cycles: eligible_cycles,
      attempted: attempted,
      expected_capacity: capacity,
      capacity_utilization: ratio(attempted, capacity),
      population_coverage: ratio(selected_population, population),
      never_selected: population - selected_population,
      min_selections_among_served: min_selected,
      max_selections: max_selected,
      selection_spread: max_selected - min_selected,
      deferred_opportunities: max(0, population * eligible_cycles - attempted),
      runtime_us: runtime_us,
      runtime_us_per_eligible_cycle: ratio(runtime_us, eligible_cycles),
      runtime_us_per_attempt: ratio(runtime_us, attempted)
    }
  end

  defp identity(index),
    do: "dormant_#{String.pad_leading(Integer.to_string(index), 8, "0")}" 

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  defp normalize_positive(value, _fallback) when is_integer(value) and value > 0, do: value
  defp normalize_positive(_value, fallback), do: fallback

  defp normalize_positive_list(values, fallback) when is_list(values) do
    values
    |> Enum.filter(&(is_integer(&1) and &1 > 0))
    |> Enum.uniq()
    |> Enum.sort()
    |> case do
      [] -> fallback
      normalized -> normalized
    end
  end

  defp normalize_positive_list(_values, fallback), do: fallback

  defp normalize_non_negative_list(values, fallback) when is_list(values) do
    values
    |> Enum.filter(&(is_integer(&1) and &1 >= 0))
    |> Enum.uniq()
    |> Enum.sort()
    |> case do
      [] -> fallback
      normalized -> normalized
    end
  end

  defp normalize_non_negative_list(_values, fallback), do: fallback
end
