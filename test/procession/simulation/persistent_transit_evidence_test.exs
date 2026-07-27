defmodule Procession.Simulation.PersistentTransitEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LivingBriarRuntime

  @tag :persistent_transit_evidence
  test "prints persistent transit evidence" do
    for opts <- [
          [seed: 19, budget: 3, cadence: 1],
          [seed: 41, budget: 3, cadence: 1],
          [seed: 77, budget: 3, cadence: 1],
          [seed: 41, budget: 1, cadence: 4]
        ] do
      {:ok, runtime} = LivingBriarRuntime.start_link(opts)
      Enum.each(1..128, fn _ -> assert {:ok, _} = LivingBriarRuntime.step(runtime) end)
      summary = LivingBriarRuntime.snapshot(runtime)

      IO.puts(
        "PERSISTENT_TRANSIT_EVIDENCE " <>
          inspect(%{
            seed: summary.seed,
            budget: summary.budget,
            cadence: summary.cadence,
            ticks: summary.tick,
            decisions: summary.decisions,
            deferred: summary.deferred,
            transit_selected: Map.get(summary.primitives, :cross_region_boundary, 0),
            transit_starts: summary.transit_starts,
            transit_progress: summary.transit_progress,
            transit_arrivals: summary.transit_arrivals,
            transit_stranded: summary.transit_stranded,
            migrations: summary.migrations,
            active_transit:
              Enum.count(summary.resident_processes, fn {_id, process} ->
                process.primitive == :cross_region_boundary
              end),
            populations: summary.populations,
            material_error: summary.material_accounting_error,
            minds_committed: summary.archived_minds_committed?
          })
      )

      assert summary.archived_minds_committed?
      assert abs(summary.material_accounting_error) < 1.0e-8
      assert summary.transit_progress >= summary.transit_arrivals
      LivingBriarRuntime.stop(runtime)
    end
  end
end
