defmodule Procession.Simulation.FlowNetworkTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.FlowNetwork

  test "accounts for entered, transferred, retained, and unresolved quantity" do
    network =
      FlowNetwork.new()
      |> FlowNetwork.add_transition(:source, :left, resistance: 0.4)
      |> FlowNetwork.add_transition(:source, :right, resistance: 0.8)
      |> FlowNetwork.add_transition(:left, :exit, resistance: 0.5)
      |> FlowNetwork.add_transition(:right, :exit, resistance: 0.5)

    result =
      FlowNetwork.run(network, %{source: 1.0}, [:exit],
        threshold: 0.001,
        attenuation: 0.97,
        permeability_scale: 0.5,
        max_ticks: 4
      )

    assert FlowNetwork.conserved?(result)
    assert Map.get(result.transferred, :exit, 0.0) > 0.0
    assert result.unresolved > 0.0
  end

  test "absolute resistance affects a single available transition" do
    open = FlowNetwork.new() |> FlowNetwork.add_transition(:a, :exit, resistance: 0.2)
    restricted = FlowNetwork.new() |> FlowNetwork.add_transition(:a, :exit, resistance: 1.2)

    opts = [threshold: 0.001, attenuation: 1.0, permeability_scale: 1.0, max_ticks: 2]
    open_result = FlowNetwork.run(open, %{a: 1.0}, [:exit], opts)
    restricted_result = FlowNetwork.run(restricted, %{a: 1.0}, [:exit], opts)

    assert open_result.transferred.exit > restricted_result.transferred.exit
  end
end
