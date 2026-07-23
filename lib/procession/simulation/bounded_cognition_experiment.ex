defmodule Procession.Simulation.BoundedCognitionExperiment do
  @moduledoc """
  A narrow prospective-action probe for bounded cognition.

  A fed but cooling learner near food has two opaque candidates. Reactive selection
  favors remaining because its immediate remembered value is higher. Thought projects
  both candidates across several internal transitions and can discover that one route
  improves warmth. No internal operation changes the physical world.
  """

  alias Procession.Simulation.BoundedCognition

  @candidates [:pattern_a, :pattern_b]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 32)
    ticks = Keyword.get(opts, :ticks, 12)
    budget = Keyword.get(opts, :cognitive_budget, 8)
    seed = Keyword.get(opts, :seed, 41)

    rows = for entity <- 1..population, do: run_one(entity, ticks, budget, seed)

    %{
      population: population,
      ticks: ticks,
      cognitive_budget: budget,
      rows: rows,
      summary: %{
        world_ticks_advanced: Enum.sum(Enum.map(rows, & &1.world_ticks)),
        mean_work_per_tick: mean(Enum.map(rows, & &1.mean_work_per_tick)),
        mean_operations_per_tick: mean(Enum.map(rows, & &1.mean_operations_per_tick)),
        thought_changed_choice_rate: fraction(rows, & &1.changed_choice?),
        warm_route_selection_rate: fraction(rows, &(&1.selected == :pattern_b)),
        mean_projected_depth: mean(Enum.map(rows, & &1.projected_depth)),
        unfinished_after_first_tick_rate: fraction(rows, & &1.unfinished_after_first_tick?)
      }
    }
  end

  def report(result) do
    s = result.summary

    Enum.join([
      "Bounded cognition prospective-action probe",
      "population=#{result.population} ticks=#{result.ticks} budget=#{result.cognitive_budget}",
      "world_ticks_advanced=#{s.world_ticks_advanced}",
      "mean_work_per_tick=#{fmt(s.mean_work_per_tick)}",
      "mean_operations_per_tick=#{fmt(s.mean_operations_per_tick)}",
      "unfinished_after_first_tick=#{fmt(s.unfinished_after_first_tick_rate)}",
      "mean_projected_depth=#{fmt(s.mean_projected_depth)}",
      "thought_changed_choice=#{fmt(s.thought_changed_choice_rate)}",
      "warm_route_selection=#{fmt(s.warm_route_selection_rate)}"
    ], "\n")
  end

  defp run_one(entity, ticks, budget, seed) do
    immediate = %{pattern_a: 0.62, pattern_b: 0.44}
    baseline = Enum.max_by(@candidates, &{Map.fetch!(immediate, &1), &1})

    continuation = %{
      phase: :recall,
      candidate_index: 0,
      depth: 0,
      horizon: 4,
      values: immediate,
      recalled: []
    }

    initial = BoundedCognition.new(continuation, baseline_action: baseline)

    {final, snapshots} =
      Enum.reduce(1..ticks, {initial, []}, fn tick, {state, snapshots} ->
        next = BoundedCognition.run_tick(state, step_fun(entity, seed, tick), cognitive_budget: budget)
        {next, [next | snapshots]}
      end)

    first = List.last(snapshots)
    work = Enum.map(snapshots, & &1.last_tick_work)
    operations = Enum.map(snapshots, & &1.last_tick_operations)

    %{
      entity: entity,
      world_ticks: ticks,
      selected: final.intended_action || baseline,
      baseline: baseline,
      changed_choice?: final.decision_influence > 0,
      projected_depth: final.continuation.depth * 1.0,
      unfinished_after_first_tick?: is_nil(first.intended_action),
      mean_work_per_tick: mean(work),
      mean_operations_per_tick: mean(operations)
    }
  end

  defp step_fun(entity, seed, tick) do
    fn continuation, _remaining ->
      case continuation.phase do
        :recall ->
          candidate = Enum.at(@candidates, continuation.candidate_index)
          recalled = [candidate | continuation.recalled]
          next_index = continuation.candidate_index + 1

          next =
            if next_index >= length(@candidates),
              do: %{continuation | phase: :project, candidate_index: 0, recalled: recalled},
              else: %{continuation | candidate_index: next_index, recalled: recalled}

          {:continue, {:recall, 1, candidate}, next}

        :project when continuation.depth < continuation.horizon ->
          candidate = Enum.at(@candidates, continuation.candidate_index)
          delta = projected_delta(candidate, continuation.depth, entity, seed, tick)
          values = Map.update!(continuation.values, candidate, &(&1 + delta))
          next_index = rem(continuation.candidate_index + 1, length(@candidates))
          depth = if next_index == 0, do: continuation.depth + 1, else: continuation.depth
          next = %{continuation | values: values, candidate_index: next_index, depth: depth}
          {:continue, {:project, 2, {candidate, depth, delta}}, next}

        :project ->
          {:continue, {:compare, 1, continuation.values}, %{continuation | phase: :compare}}

        :compare ->
          selected = Enum.max_by(@candidates, &{Map.fetch!(continuation.values, &1), &1})
          {:commit, selected, %{continuation | phase: :committed}}

        :committed ->
          {:stop, continuation}
      end
    end
  end

  defp projected_delta(:pattern_a, depth, entity, seed, tick) do
    jitter = (:erlang.phash2({:stay, entity, seed, tick, depth}, 100) - 50) / 100_000
    -0.11 - depth * 0.015 + jitter
  end

  defp projected_delta(:pattern_b, depth, entity, seed, tick) do
    jitter = (:erlang.phash2({:home, entity, seed, tick, depth}, 100) - 50) / 100_000
    0.04 + depth * 0.035 + jitter
  end

  defp fraction([], _predicate), do: 0.0
  defp fraction(rows, predicate), do: Enum.count(rows, predicate) / length(rows)
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end
