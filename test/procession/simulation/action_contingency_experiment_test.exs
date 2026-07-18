defmodule Procession.Simulation.ActionContingencyExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.ActionContingencyExperiment, as: Experiment

  test "comparison includes reliable and noisy motor regimes" do
    results = Experiment.compare(ticks: 40, seeds: Enum.to_list(1..4))

    assert Map.has_key?(results, {:reliable, :reactive})
    assert Map.has_key?(results, {:reliable, :contingency_adaptive})
    assert Map.has_key?(results, {:noisy, :outcome_adaptive})
  end

  test "contingency learner confirms only temporally overlapping action effects" do
    state = Experiment.run(
      variant: :contingency_adaptive,
      motor_mode: :reliable,
      ticks: 80,
      seed: 7,
      effect_delay: 2
    )

    assert state.confirmed_contingencies > 0
    assert state.false_credit == 0
  end

  test "local traces are tied to specific entity events" do
    state = Experiment.run(ticks: 3, seed: 7)

    assert Enum.any?(Map.keys(state.traces), fn
      {:action, tick, action} when is_integer(tick) and is_atom(action) -> true
      _ -> false
    end)
  end

  test "world-facing state does not expose a causal history API" do
    state = Experiment.run(ticks: 1)

    refute Map.has_key?(state, :world_provenance)
    refute Map.has_key?(state, :cause_graph)
    assert is_map(state.traces)
    assert :explicit_world_provenance in Experiment.missing_couplings()
  end
end
