defmodule Procession.Simulation.ResidentPersistentActionsEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LivingBriarRuntime

  @tag :resident_process_evidence
  test "prints resident persistent action evidence" do
    for opts <- [
          [seed: 19, budget: 3, cadence: 1],
          [seed: 41, budget: 3, cadence: 1],
          [seed: 77, budget: 3, cadence: 1],
          [seed: 41, budget: 1, cadence: 4]
        ] do
      {:ok, runtime} = LivingBriarRuntime.start_link(opts)
      Enum.each(1..64, fn _ -> assert {:ok, _} = LivingBriarRuntime.step(runtime) end)
      summary = LivingBriarRuntime.snapshot(runtime)

      IO.puts("RESIDENT_PROCESS_EVIDENCE " <> inspect(%{
        seed: summary.seed,
        budget: summary.budget,
        cadence: summary.cadence,
        ticks: summary.tick,
        decisions: summary.decisions,
        deferred: summary.deferred,
        migrations: summary.migrations,
        starts: summary.resident_process_starts,
        progress: summary.resident_process_progress,
        redirects: summary.resident_process_redirects,
        interruptions: summary.resident_process_interruptions,
        endings: summary.resident_process_endings,
        active: map_size(summary.resident_processes),
        populations: summary.populations,
        primitives: summary.primitives,
        material_error: summary.material_accounting_error,
        minds_committed: summary.archived_minds_committed?
      }))

      assert summary.resident_process_starts > 0
      assert summary.resident_process_progress > 0
      assert abs(summary.material_accounting_error) < 1.0e-8
      assert summary.archived_minds_committed?
      LivingBriarRuntime.stop(runtime)
    end
  end
end
