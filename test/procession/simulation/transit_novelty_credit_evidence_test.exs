defmodule Procession.Simulation.TransitNoveltyCreditEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.TransitAwareLivingBriarRuntime

  @tag timeout: 120_000
  test "prints novelty-credit transit evidence" do
    for seed <- [19, 41, 77] do
      {:ok, runtime} =
        TransitAwareLivingBriarRuntime.start_link(
          seed: seed,
          budget: 3,
          cadence: 1,
          transit_budget: 2,
          transit_cadence: 1
        )

      Enum.each(1..96, fn _ -> assert {:ok, _} = TransitAwareLivingBriarRuntime.step(runtime) end)
      summary = TransitAwareLivingBriarRuntime.snapshot(runtime)

      IO.puts(
        "TRANSIT_NOVELTY_CREDIT_EVIDENCE " <>
          inspect(%{
            seed: seed,
            transit_thoughts: summary.in_transit_decisions,
            motor_impulses: summary.transit_motor_impulses,
            forward_ticks: summary.transit_forward_ticks,
            reverse_ticks: summary.transit_reversals,
            stationary_ticks: summary.transit_stationary_ticks,
            returns: summary.transit_returns,
            arrivals: summary.transit_arrivals,
            stranded: summary.transit_stranded,
            active_transit: Enum.count(summary.resident_processes, fn {_id, process} ->
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
      assert summary.transit_cognitive_primitives in [%{}, %{motor_impulse: summary.in_transit_decisions}]
      assert abs(summary.material_accounting_error) < 1.0e-8
      TransitAwareLivingBriarRuntime.stop(runtime)
    end
  end
end
