defmodule Procession.Simulation.HomeForagingSeedReplication do
  @moduledoc "Replicates the slow long-lived foraging result across disjoint seeds."

  alias Procession.Simulation.HomeForagingContingencyExperiment, as: Experiment

  @conditions [:abrupt_assistance, :staged_assistance]
  @default_seeds [101, 211, 307, 401, 503]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seeds = Keyword.get(opts, :seeds, @default_seeds)

    experiment_opts = Keyword.drop(opts, [:seeds])

    seed_results =
      Enum.map(seeds, fn seed ->
        result = Experiment.run(Keyword.merge(experiment_opts, population: population, seed: seed))
        slow_rows = Enum.filter(result.rows, &(&1.variant == :slow_long_lived))
        %{seed: seed, rows: slow_rows, summary: summarize_rows(slow_rows, population)}
      end)

    all_rows = Enum.flat_map(seed_results, &tag_seed/1)

    %{
      seeds: seeds,
      population_per_seed: population,
      total_per_condition: population * length(seeds),
      seed_results: seed_results,
      summary: summarize_rows(all_rows, population * length(seeds)),
      diagnostics: diagnostics(all_rows)
    }
  end

  def report(result) do
    seed_lines =
      Enum.flat_map(result.seed_results, fn seed_result ->
        Enum.map(@conditions, fn condition ->
          s = seed_result.summary[condition]

          "seed=#{seed_result.seed} #{condition}: " <>
            "reached=#{s.reached}/#{s.population} collected=#{s.collected}/#{s.population} " <>
            "returned=#{s.returned}/#{s.population} consumed=#{s.consumed}/#{s.population} " <>
            "contexts=#{fmt(s.contexts)} blocked=#{fmt(s.blocked_repeat)} ticks=#{fmt(s.ticks)}"
        end)
      end)

    aggregate_lines =
      Enum.map(@conditions, fn condition ->
        s = result.summary[condition]
        d = result.diagnostics[condition]

        "aggregate #{condition}: reached=#{s.reached}/#{s.population} " <>
          "collected=#{s.collected}/#{s.population} returned=#{s.returned}/#{s.population} " <>
          "consumed=#{s.consumed}/#{s.population} survived=#{s.survived}/#{s.population} " <>
          "seed_consumed_range=#{d.seed_consumed_min}-#{d.seed_consumed_max} " <>
          "contexts_consumed=#{fmt(d.contexts_consumed)} contexts_failed=#{fmt(d.contexts_failed)} " <>
          "blocked_consumed=#{fmt(d.blocked_consumed)} blocked_failed=#{fmt(d.blocked_failed)} " <>
          "ticks_consumed=#{fmt(d.ticks_consumed)} ticks_failed=#{fmt(d.ticks_failed)} " <>
          "corr_context=#{fmt(d.corr_context)} corr_blocked=#{fmt(d.corr_blocked)} " <>
          "corr_useful=#{fmt(d.corr_useful)} corr_ticks=#{fmt(d.corr_ticks)}"
      end)

    Enum.join([
      "Slow long-lived home-foraging multi-seed replication",
      "seeds=#{Enum.join(result.seeds, ",")} population_per_seed=#{result.population_per_seed} " <>
        "total_per_condition=#{result.total_per_condition}"
      | seed_lines ++ aggregate_lines
    ], "\n")
  end

  defp tag_seed(%{seed: seed, rows: rows}), do: Enum.map(rows, &Map.put(&1, :seed, seed))

  defp summarize_rows(rows, population) do
    Map.new(@conditions, fn condition ->
      selected = Enum.filter(rows, &(&1.condition == condition))

      {condition,
       %{
         population: population,
         survived: Enum.count(selected, & &1.survived),
         reached: Enum.count(selected, & &1.reached),
         collected: Enum.count(selected, & &1.collected),
         returned: Enum.count(selected, & &1.returned),
         consumed: Enum.count(selected, & &1.consumed),
         contexts: mean(Enum.map(selected, &(&1.context_end * 1.0))),
         blocked_repeat: mean(Enum.map(selected, & &1.blocked_repeat)),
         useful_repeat: mean(Enum.map(selected, & &1.useful_repeat)),
         ticks: median(Enum.map(selected, &(&1.ticks * 1.0)))
       }}
    end)
  end

  defp diagnostics(rows) do
    Map.new(@conditions, fn condition ->
      selected = Enum.filter(rows, &(&1.condition == condition))
      consumed = Enum.filter(selected, & &1.consumed)
      failed = Enum.reject(selected, & &1.consumed)

      per_seed =
        selected
        |> Enum.group_by(& &1.seed)
        |> Enum.map(fn {_seed, seed_rows} -> Enum.count(seed_rows, & &1.consumed) end)

      {condition,
       %{
         seed_consumed_min: Enum.min(per_seed, fn -> 0 end),
         seed_consumed_max: Enum.max(per_seed, fn -> 0 end),
         contexts_consumed: mean_context(consumed),
         contexts_failed: mean_context(failed),
         blocked_consumed: mean_field(consumed, :blocked_repeat),
         blocked_failed: mean_field(failed, :blocked_repeat),
         useful_consumed: mean_field(consumed, :useful_repeat),
         useful_failed: mean_field(failed, :useful_repeat),
         ticks_consumed: median_field(consumed, :ticks),
         ticks_failed: median_field(failed, :ticks),
         corr_context: point_biserial_context(selected),
         corr_blocked: point_biserial(selected, :blocked_repeat),
         corr_useful: point_biserial(selected, :useful_repeat),
         corr_ticks: point_biserial(selected, :ticks)
       }}
    end)
  end

  defp point_biserial_context(rows) do
    xs = Enum.map(rows, &(&1.context_end * 1.0))
    ys = Enum.map(rows, &(if &1.consumed, do: 1.0, else: 0.0))
    correlation(xs, ys)
  end

  defp point_biserial([], _field), do: 0.0
  defp point_biserial(rows, field) do
    xs = Enum.map(rows, &(Map.fetch!(&1, field) * 1.0))
    ys = Enum.map(rows, &(if &1.consumed, do: 1.0, else: 0.0))
    correlation(xs, ys)
  end

  defp correlation(xs, ys) do
    mx = mean(xs)
    my = mean(ys)
    numerator = Enum.zip(xs, ys) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + (x - mx) * (y - my) end)
    dx = :math.sqrt(Enum.reduce(xs, 0.0, fn x, acc -> acc + :math.pow(x - mx, 2) end))
    dy = :math.sqrt(Enum.reduce(ys, 0.0, fn y, acc -> acc + :math.pow(y - my, 2) end))
    if dx == 0.0 or dy == 0.0, do: 0.0, else: numerator / (dx * dy)
  end

  defp mean_context(rows), do: rows |> Enum.map(&(&1.context_end * 1.0)) |> mean()
  defp mean_field(rows, field), do: rows |> Enum.map(&(Map.fetch!(&1, field) * 1.0)) |> mean()
  defp median_field(rows, field), do: rows |> Enum.map(&(Map.fetch!(&1, field) * 1.0)) |> median()
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)
    if rem(length(sorted), 2) == 1,
      do: Enum.at(sorted, middle),
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
