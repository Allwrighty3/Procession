defmodule Procession.Simulation.DevelopmentalFieldCompetitionTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalField

  test "each active source reinforces only its strongest local competitors" do
    opts = [
      micro_nodes: 256,
      input_width: 1,
      activity_retention: 0.0,
      plasticity_fanout: 2,
      plasticity_budget: 0.2,
      consolidation_threshold: 99
    ]

    features = Enum.map(1..10, &{:feature, &1})
    state = DevelopmentalField.step(DevelopmentalField.new(opts), {:features, features}, opts)

    outgoing_counts =
      state.edges
      |> Map.keys()
      |> Enum.group_by(&elem(&1, 0))
      |> Map.values()
      |> Enum.map(&length/1)

    assert outgoing_counts != []
    assert Enum.all?(outgoing_counts, &(&1 <= 2))
  end
end