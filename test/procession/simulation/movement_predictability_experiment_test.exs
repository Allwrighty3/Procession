defmodule Procession.Simulation.MovementPredictabilityExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.MovementPredictabilityExperiment, as: Experiment

  test "comparison covers predictable drift and abrupt teleport movement" do
    results = Experiment.compare(ticks: 80, seeds: Enum.to_list(1..8))

    assert Map.has_key?(results, {:teleport, :reactive})
    assert Map.has_key?(results, {:teleport, :adaptive})
    assert Map.has_key?(results, {:drift, :reactive})
    assert Map.has_key?(results, {:drift, :adaptive})
  end

  test "movement regimes expose different source histories" do
    teleport = Experiment.run(mode: :teleport, variant: :reactive, ticks: 12, source_interval: 4)
    drift = Experiment.run(mode: :drift, variant: :reactive, ticks: 12, drift_step_interval: 1)

    teleport_sources = teleport.history |> Enum.map(& &1.source) |> Enum.uniq()
    drift_sources = drift.history |> Enum.map(& &1.source) |> Enum.uniq()

    assert length(drift_sources) > length(teleport_sources)
  end

  test "missing coupling ledger remains explicit" do
    assert :explicit_self_motion_sensing in Experiment.missing_couplings()
    assert :temporal_prediction in Experiment.missing_couplings()
  end
end
