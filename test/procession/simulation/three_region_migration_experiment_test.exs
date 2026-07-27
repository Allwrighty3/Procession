defmodule Procession.Simulation.ThreeRegionMigrationExperimentTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.ThreeRegionMigrationExperiment

  test "runs real bounded dormant cognition across three inert regions" do
    result = ThreeRegionMigrationExperiment.run(ticks: 8, budget: 2, cadence: 1, seed: 41)

    assert result.experiment == :three_region_migration
    assert result.regions == [:western_hollow, :river_market, :eastern_ridge]
    assert length(result.identities) == 3
    assert result.destination_metadata_present? == false
    assert length(result.traces) == 8
    assert result.totals.attempted > 0
    assert result.totals.succeeded > 0
    assert result.totals.runtime_us >= 0

    assert Enum.all?(result.identities, fn identity ->
             Map.keys(identity) |> Enum.sort() == [:energy, :history, :id, :inventory, :region]
           end)

    assert Enum.any?(result.traces, fn trace -> trace.decisions != [] end)
  end

  test "budget and cadence bound dormant decision opportunities" do
    sparse = ThreeRegionMigrationExperiment.run(ticks: 8, budget: 1, cadence: 2, seed: 41)
    dense = ThreeRegionMigrationExperiment.run(ticks: 8, budget: 3, cadence: 1, seed: 41)

    assert sparse.totals.attempted <= 4
    assert dense.totals.attempted >= sparse.totals.attempted
    assert sparse.totals.deferred >= 0
  end

  test "observable traces contain consequences rather than hidden destination truth" do
    result = ThreeRegionMigrationExperiment.run(ticks: 6, budget: 3, cadence: 1, seed: 17)

    Enum.each(result.traces, fn trace ->
      assert Map.has_key?(trace, :travel_events)
      assert Map.has_key?(trace, :decisions)
      assert Map.has_key?(trace, :locations)
      assert Map.has_key?(trace, :commitments)
      refute Map.has_key?(trace, :correct_destination)
      refute Map.has_key?(trace, :journey_complete)
    end)
  end
end
