defmodule Procession.Simulation.InTransitCognitionEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.TransitAwareLivingBriarRuntime

  @tag :in_transit_cognition_evidence
  test "prints in-transit cognition evidence" do
    for opts <- [
          [seed: 19, budget: 3, cadence: 1, transit_budget: 1],
          [seed: 41, budget: 3, cadence: 1, transit_budget: 1],
          [seed: 77, budget: 3, cadence: 1, transit_budget: 1],
          [seed: 41, budget: 1, cadence: 4, transit_budget: 1, transit_cadence: 2]
        ] do
      {:ok, runtime} = TransitAwareLivingBriarRuntime.start_link(opts)
      Enum.each(1..128, fn _ -> assert {:ok, _} = TransitAwareLivingBriarRuntime.step(runtime) end)
      summary = TransitAwareLivingBriarRuntime.snapshot(runtime)

      IO.puts(
        "IN_TRANSIT_COGNITION_EVIDENCE " <>
          inspect(%{
            seed: summary.seed,
            budget: summary.budget,
            cadence: summary.cadence,
            ticks: summary.tick,
            decisions: summary.decisions,
            deferred: summary.deferred,
            transit_selected: Map.get(summary.primitives, :cross_region_boundary, 0),
            transit_progress: summary.transit_progress,
            transit_arrivals: summary.transit_arrivals,
            transit_stranded: summary.transit_stranded,
            in_transit_decisions: summary.in_transit_decisions,
            transit_cognitive_primitives: summary.transit_cognitive_primitives,
            transit_continuations: summary.transit_continuations,
            transit_cognitive_pauses: summary.transit_cognitive_pauses,
            transit_reversals: summary.transit_reversals,
            transit_returns: summary.transit_returns,
            active_transit:
              Enum.count(summary.resident_processes, fn {_id, process} ->
                process.primitive == :cross_region_boundary
              end),
            populations: summary.populations,
            material_error: summary.material_accounting_error,
            regional_minds_committed: summary.archived_minds_committed?,
            transit_minds_committed: summary.transit_minds_committed?
          })
      )

      assert summary.archived_minds_committed?
      assert summary.transit_minds_committed?
      assert abs(summary.material_accounting_error) < 1.0e-8
      assert Enum.sum(Map.values(summary.populations)) +
               Enum.count(summary.resident_processes, fn {_id, process} ->
                 process.primitive == :cross_region_boundary
               end) == 6

      TransitAwareLivingBriarRuntime.stop(runtime)
    end
  end
end
