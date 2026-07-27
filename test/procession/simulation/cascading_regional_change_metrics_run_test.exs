defmodule Procession.Simulation.CascadingRegionalChangeMetricsRunTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.CascadingRegionalChangeExperiment

  @tag :cascading_metrics_run
  test "emit cascading regional change evidence matrix" do
    runs =
      Enum.map([19, 41, 77], fn seed ->
        result = CascadingRegionalChangeExperiment.run(ticks: 64, budget: 3, cadence: 1, seed: seed)
        {seed, summarize(result)}
      end)

    constrained =
      CascadingRegionalChangeExperiment.run(ticks: 64, budget: 1, cadence: 4, seed: 41)
      |> summarize()

    IO.puts("CASCADE_EVIDENCE_BEGIN")
    IO.inspect(%{normal: runs, constrained: constrained}, pretty: true, limit: :infinity)
    IO.puts("CASCADE_EVIDENCE_END")

    assert Enum.all?(runs, fn {_seed, run} -> run.failed == 0 end)
    assert constrained.failed == 0
  end

  defp summarize(result) do
    %{
      attempted: result.totals.attempted,
      succeeded: result.totals.succeeded,
      failed: result.totals.failed,
      deferred: result.totals.deferred,
      location_changes: result.totals.location_changes,
      entered_regions: result.totals.entered_regions,
      runtime_us: result.totals.runtime_us,
      runtime_us_per_tick: result.totals.runtime_us_per_tick,
      final_locations: result.final_locations,
      final_regions: result.final_regions,
      analysis: result.analysis,
      snapshot_metrics: result.snapshot_metrics,
      live_entity_process_peak: result.live_entity_process_peak
    }
  end
end
