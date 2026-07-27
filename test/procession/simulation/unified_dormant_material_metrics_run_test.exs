defmodule Procession.Simulation.UnifiedDormantMaterialMetricsRunTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.UnifiedDormantMaterialExperiment

  @tag :unified_dormant_material_metrics
  test "emit unified dormant material evidence matrix" do
    normal =
      Enum.map([19, 41, 77], fn seed ->
        result = UnifiedDormantMaterialExperiment.run(ticks: 96, budget: 3, cadence: 1, seed: seed)
        {seed, summarize(result)}
      end)

    constrained =
      UnifiedDormantMaterialExperiment.run(ticks: 96, budget: 1, cadence: 4, seed: 41)
      |> summarize()

    IO.puts("UNIFIED_DORMANT_MATERIAL_BEGIN")
    IO.inspect(%{normal: normal, constrained: constrained}, pretty: true, limit: :infinity)
    IO.puts("UNIFIED_DORMANT_MATERIAL_END")

    assert Enum.all?(normal, fn {_seed, run} -> run.failures == 0 end)
    assert Enum.all?(normal, fn {_seed, run} -> run.archived_minds_committed? end)
  end

  defp summarize(result) do
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
      material_primitives_observed?: result.analysis.material_primitives_observed?,
      population_changed?: result.analysis.population_changed?,
      pressure_changed?: result.analysis.pressure_changed?,
      cascade_observed?: result.analysis.cascade_observed?
    }
  end
end
