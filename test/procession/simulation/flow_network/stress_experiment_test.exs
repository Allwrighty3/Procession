defmodule Procession.Simulation.FlowNetwork.StressExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.FlowNetwork
  alias Procession.Simulation.FlowNetwork.StressExperiment

  test "damage changes later stress propagation without cognition" do
    result = StressExperiment.run()

    first_far = Map.get(result.first.flows, {:impact, :far}, 0.0)
    second_far = Map.get(result.second.flows, {:impact, :far}, 0.0)

    assert result.events != []
    assert second_far > first_far
    assert FlowNetwork.conserved?(result.first)
    assert FlowNetwork.conserved?(result.second)
  end

  test "report and ledger expose experiment boundaries" do
    result = StressExperiment.run()

    assert result.report =~ "First impact"
    assert result.report =~ "Structural changes"
    assert :heat_receiver in StressExperiment.missing_couplings()
  end
end
