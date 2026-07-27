defmodule Procession.Simulation.TransitForceProjectionEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.TransitAwareLivingBriarRuntime

  @tag :transit_force_projection_evidence
  test "prints force-projected transit evidence" do
    for opts <- [
          [seed: 19, budget: 3, cadence: 1, transit_budget: 2, transit_cadence: 1],
          [seed: 41, budget: 3, cadence: 1, transit_budget: 2, transit_cadence: 1],
          [seed: 77, budget: 3, cadence: 1, transit_budget: 2, transit_cadence: 1],
          [seed: 41, budget: 1, cadence: 4, transit_budget: 1, transit_cadence: 4]
        ] do
      {:ok, runtime} = TransitAwareLivingBriarRuntime.start_link(opts)
      Enum.each(1..192, fn _ -> assert {:ok, _} = TransitAwareLivingBriarRuntime.step(runtime) end)
      summary = TransitAwareLivingBriarRuntime.snapshot(runtime)
      events = summary.resident_process_events
      transit_decisions = Enum.filter(summary.resident_process_events, &(&1.primitive == :cross_region_boundary))

      IO.puts(
        "TRANSIT_FORCE_PROJECTION_EVIDENCE " <>
          inspect(%{
            seed: summary.seed,
            budget: summary.budget,
            cadence: summary.cadence,
            decisions: summary.decisions,
            transit_thoughts: summary.in_transit_decisions,
            motor_impulses: summary.transit_motor_impulses,
            advancing_ticks: summary.transit_forward_ticks,
            reversing_ticks: summary.transit_reversals,
            stationary_ticks: summary.transit_stationary_ticks,
            source_returns: summary.transit_returns,
            arrivals: summary.transit_arrivals,
            stranded: summary.transit_stranded,
            active_transit: Enum.count(summary.resident_processes, fn {_id, process} ->
              process.primitive == :cross_region_boundary
            end),
            lateral_motion_ticks: Enum.count(transit_decisions, fn event ->
              abs(Map.get(event, :lateral_position, 0.0)) > 1.0e-6
            end),
            populations: summary.populations,
            material_error: summary.material_accounting_error,
            regional_minds_committed: summary.archived_minds_committed?,
            transit_minds_committed: summary.transit_minds_committed?,
            event_count: length(events)
          })
      )

      assert summary.archived_minds_committed?
      assert summary.transit_minds_committed?
      assert abs(summary.material_accounting_error) < 1.0e-8
      assert summary.transit_cognitive_primitives in [%{}, %{motor_impulse: summary.in_transit_decisions}]
      assert summary.transit_stationary_ticks + summary.transit_forward_ticks + summary.transit_reversals > 0
      TransitAwareLivingBriarRuntime.stop(runtime)
    end
  end
end
