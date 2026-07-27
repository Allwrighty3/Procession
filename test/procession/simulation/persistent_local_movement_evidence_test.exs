defmodule Procession.Simulation.PersistentLocalMovementEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LivingBriarRuntime

  @tag :persistent_local_movement_evidence
  test "prints persistent local movement evidence" do
    for opts <- [
          [seed: 19, budget: 3, cadence: 1],
          [seed: 41, budget: 3, cadence: 1],
          [seed: 77, budget: 3, cadence: 1],
          [seed: 41, budget: 1, cadence: 4]
        ] do
      {:ok, runtime} = LivingBriarRuntime.start_link(opts)
      Enum.each(1..96, fn _ -> assert {:ok, _} = LivingBriarRuntime.step(runtime) end)
      summary = LivingBriarRuntime.snapshot(runtime)

      movement_events =
        Enum.filter(summary.resident_process_events, &(&1.primitive == :move_local))

      IO.puts(
        "PERSISTENT_LOCAL_MOVEMENT_EVIDENCE " <>
          inspect(%{
            seed: summary.seed,
            budget: summary.budget,
            cadence: summary.cadence,
            ticks: summary.tick,
            decisions: summary.decisions,
            deferred: summary.deferred,
            migrations: summary.migrations,
            movement_selected: Map.get(summary.primitives, :move_local, 0),
            movement_starts: Enum.count(movement_events, &(&1.status == :started)),
            movement_progress: Enum.count(movement_events, &(&1.status == :continuing)),
            movement_endings: Enum.count(movement_events, &(&1.status == :ended)),
            gathering_progress:
              Enum.count(summary.resident_process_events, fn event ->
                event.primitive == :contact_loose_raw and event.amount > 0.0
              end),
            body_contact_endings:
              Enum.count(summary.resident_process_events, fn event ->
                event.primitive == :contact_body and event.status == :ended
              end),
            populations: summary.populations,
            material_error: summary.material_accounting_error,
            minds_committed: summary.archived_minds_committed?
          })
      )

      assert summary.archived_minds_committed?
      assert abs(summary.material_accounting_error) < 1.0e-8
      assert Map.get(summary.primitives, :move_local, 0) > 0
      assert Enum.any?(movement_events, &(&1.amount > 0.0))
      LivingBriarRuntime.stop(runtime)
    end
  end
end
