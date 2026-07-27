defmodule Procession.Simulation.LivingBriar do
  @moduledoc """
  Canonical observable living-world scenario for Procession.

  This module is the stable entry point shared by demos, tests, and metrics. It delegates
  physical execution to the current unified dormant-material simulation while presenting a
  compact observer-facing trace. Callers should depend on this boundary rather than constructing
  another private three-region fixture.
  """

  alias Procession.Simulation.UnifiedDormantMaterialExperiment

  @default_ticks 32
  @default_budget 3
  @default_cadence 1
  @default_seed 41

  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:ticks, @default_ticks)
      |> Keyword.put_new(:budget, @default_budget)
      |> Keyword.put_new(:cadence, @default_cadence)
      |> Keyword.put_new(:seed, @default_seed)

    result = UnifiedDormantMaterialExperiment.run(opts)

    %{
      scenario: :living_briar,
      configuration: %{
        ticks: result.ticks,
        budget: result.budget,
        cadence: result.cadence,
        seed: result.seed
      },
      summary: summary(result),
      observations: Enum.map(result.traces, &observe_tick/1),
      evidence: result
    }
  end

  @spec latest(map()) :: map() | nil
  def latest(%{observations: observations}) when is_list(observations), do: List.last(observations)
  def latest(_result), do: nil

  @spec changes(map()) :: [map()]
  def changes(%{observations: observations}) when is_list(observations) do
    Enum.filter(observations, fn observation ->
      observation.decisions != [] or observation.population_changed?
    end)
  end

  def changes(_result), do: []

  @spec format(map()) :: String.t()
  def format(%{scenario: :living_briar} = run) do
    lines =
      run
      |> changes()
      |> Enum.map(&format_observation/1)

    header = [
      "Living Briar",
      "ticks=#{run.configuration.ticks} budget=#{run.configuration.budget} cadence=#{run.configuration.cadence} seed=#{run.configuration.seed}",
      "decisions=#{run.summary.decisions} migrations=#{run.summary.migrations} deferred=#{run.summary.deferred}",
      "final populations: #{format_populations(run.summary.final_populations)}",
      ""
    ]

    Enum.join(header ++ lines, "\n")
  end

  def format(_result), do: "Invalid Living Briar result."

  defp summary(result) do
    %{
      decisions: result.totals.decisions,
      failures: result.totals.failures,
      deferred: result.totals.deferred,
      migrations: result.totals.migrations,
      primitives: result.totals.primitives,
      runtime_us_per_tick: result.totals.runtime_us_per_tick,
      final_populations: result.final_populations,
      material_accounting_error: result.material_accounting_error,
      archived_minds_committed?: result.analysis.archived_minds_committed?,
      population_changed?: result.analysis.population_changed?,
      pressure_changed?: result.analysis.pressure_changed?,
      cascade_observed?: result.analysis.cascade_observed?
    }
  end

  defp observe_tick(trace) do
    %{
      tick: trace.tick,
      populations: trace.populations,
      pressures: trace.pressures,
      deferred: trace.deferred,
      population_changed?: false,
      decisions: Enum.map(trace.decisions, &observe_decision/1)
    }
  end

  defp observe_decision(%{error: reason} = decision) do
    %{
      identity: decision.identity,
      region: decision.from,
      result: :failed,
      reason: reason,
      moved?: false
    }
  end

  defp observe_decision(decision) do
    %{
      identity: decision.identity,
      region: decision.from,
      primitive: decision.primitive,
      physical_consequence: decision.consequence,
      amount: decision.amount,
      motor_pattern: decision.motor_pattern,
      observed_direction: decision.motor_direction,
      moved?: decision.moved?,
      mind_committed?: match?({:ok, _}, decision.commit)
    }
  end

  defp format_observation(observation) do
    decision_lines = Enum.map(observation.decisions, &format_decision/1)

    ([
       "tick #{observation.tick} populations=#{format_populations(observation.populations)} deferred=#{observation.deferred}"
     ] ++ decision_lines)
    |> Enum.join("\n")
  end

  defp format_decision(%{result: :failed} = decision) do
    "  #{decision.identity} failed in #{decision.region}: #{inspect(decision.reason)}"
  end

  defp format_decision(decision) do
    movement = if decision.moved?, do: " moved", else: ""
    amount = if decision.amount > 0.0, do: " amount=#{Float.round(decision.amount, 4)}", else: ""

    "  #{decision.identity} @ #{decision.region}: #{decision.primitive} -> #{decision.physical_consequence}#{amount}#{movement}"
  end

  defp format_populations(populations) do
    populations
    |> Enum.sort_by(fn {region, _count} -> region end)
    |> Enum.map_join(" ", fn {region, count} -> "#{region}=#{count}" end)
  end
end
