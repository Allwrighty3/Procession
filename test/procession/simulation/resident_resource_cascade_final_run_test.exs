defmodule Procession.Simulation.ResidentResourceCascadeFinalRunTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.ResidentResourceCascadeExperiment

  @tag :resident_resource_final_run
  test "emit final contact-grounded resident resource evidence" do
    normal =
      Enum.map([19, 41, 77], fn seed ->
        result = ResidentResourceCascadeExperiment.run(ticks: 96, budget: 3, cadence: 1, seed: seed)
        {seed, summarize(result)}
      end)

    constrained =
      ResidentResourceCascadeExperiment.run(ticks: 96, budget: 1, cadence: 4, seed: 41)
      |> summarize()

    IO.puts("RESIDENT_RESOURCE_FINAL_BEGIN")
    IO.inspect(%{normal: normal, constrained: constrained}, pretty: true, limit: :infinity)
    IO.puts("RESIDENT_RESOURCE_FINAL_END")

    assert Enum.all?(normal, fn {_seed, run} -> run.cascade_observed? end)
    assert Enum.all?(normal, fn {_seed, run} -> run.transferred > 0 end)
  end

  defp summarize(result) do
    %{
      decisions: result.totals.decisions,
      moves: result.totals.moves,
      gathered: result.totals.gathered,
      transformed: result.totals.transformed,
      transferred: result.totals.transferred,
      consumed: result.totals.consumed,
      runtime_us_per_tick: result.totals.runtime_us_per_tick,
      final_populations: result.final_populations,
      population_changed?: result.analysis.population_changed?,
      pressure_changed?: result.analysis.pressure_changed?,
      material_behavior_observed?: result.analysis.material_behavior_observed?,
      interpersonal_transfer_observed?: result.analysis.interpersonal_transfer_observed?,
      cascade_observed?: result.analysis.cascade_observed?
    }
  end
end
