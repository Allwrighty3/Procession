defmodule Procession.Simulation.CascadingRegionalChangeFinalRunTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.CascadingRegionalChangeExperiment

  @tag :cascading_final_run
  test "emit final cascading evidence matrix" do
    normal =
      Enum.map([19, 41, 77], fn seed ->
        result = CascadingRegionalChangeExperiment.run(ticks: 64, budget: 3, cadence: 1, seed: seed)
        {seed, summarize(result)}
      end)

    constrained =
      CascadingRegionalChangeExperiment.run(ticks: 64, budget: 1, cadence: 4, seed: 41)
      |> summarize()

    IO.puts("CASCADE_FINAL_BEGIN")
    IO.inspect(%{normal: normal, constrained: constrained}, pretty: true, limit: :infinity)
    IO.puts("CASCADE_FINAL_END")

    assert Enum.all?(normal, fn {_seed, run} -> run.failed == 0 end)
    assert constrained.failed == 0
    assert Enum.all?(normal, fn {_seed, run} -> run.cascading_feedback_observed? end)
  end

  defp summarize(result) do
    %{
      attempted: result.totals.attempted,
      succeeded: result.totals.succeeded,
      failed: result.totals.failed,
      deferred: result.totals.deferred,
      location_changes: result.totals.location_changes,
      entered_regions: result.totals.entered_regions,
      runtime_us_per_tick: result.totals.runtime_us_per_tick,
      final_locations: result.final_locations,
      final_regions: result.final_regions,
      distinct_regions_entered: result.analysis.distinct_regions_entered,
      route_reversals: result.analysis.route_reversals,
      boundary_hesitation_ticks: result.analysis.boundary_hesitation_ticks,
      bodily_deteriorations: result.analysis.bodily_deteriorations,
      bodily_recoveries: result.analysis.bodily_recoveries,
      cascading_feedback_observed?: result.analysis.cascading_feedback_observed?,
      dynamic_conditions_changed?: result.analysis.dynamic_conditions_changed?,
      population_changed?: result.analysis.population_changed?,
      live_entity_process_peak: result.live_entity_process_peak
    }
  end
end
