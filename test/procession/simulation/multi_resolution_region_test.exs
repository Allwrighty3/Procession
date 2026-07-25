defmodule Procession.Simulation.MultiResolutionRegionTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.MultiResolutionRegion

  defp region do
    MultiResolutionRegion.new(
      id: :north,
      bounds: {10, 10},
      tick: 40,
      entities: [
        %{id: "mara", position: {2, 2}, energy: 0.8, mobility: 0.6, inventory: 0.3, consumed: 0.1},
        %{id: "oren", position: {4, 2}, energy: 0.6, mobility: 1.0, inventory: 0.2, consumed: 0.2},
        %{id: "sela", position: {3, 4}, energy: 0.7, mobility: 0.9, inventory: 0.1, consumed: 0.05}
      ],
      resources: [
        %{id: "store", position: {5, 5}, quantity: 2.1},
        %{id: "well", position: {1, 8}, quantity: 1.0}
      ],
      social_relations: %{
        {"mara", "oren", :food} => %{expectation: 0.7, confidence: 0.9, persistence: 0.4, extreme_imprint: 1.2, exposure: 12.0, last_tick: 39},
        {"sela", "mara", :movement} => %{expectation: 0.3, confidence: 0.5, persistence: 0.2, extreme_imprint: 0.0, exposure: 4.0, last_tick: 35}
      },
      causal_flags: [:injury_history, :access_disruption]
    )
  end

  test "compression retains conserved stocks and causal commitments" do
    live = region()
    coarse = MultiResolutionRegion.compress(live)
    summary = coarse.summary

    assert coarse.resolution == :coarse
    assert coarse.entities == %{}
    assert coarse.resources == %{}
    assert summary.population == 3
    assert_in_delta summary.available_stock, 3.1, 1.0e-9
    assert_in_delta summary.held_stock, 0.6, 1.0e-9
    assert_in_delta summary.consumed_stock, 0.35, 1.0e-9
    assert_in_delta summary.total_stock, 4.05, 1.0e-9
    assert summary.causal_flags == MapSet.new([:injury_history, :access_disruption])
    assert length(summary.relation_anchors) == 2
    assert MultiResolutionRegion.state_cost(coarse) < MultiResolutionRegion.state_cost(live)
  end

  test "coarse advancement transfers stock rather than inventing or deleting it" do
    coarse = region() |> MultiResolutionRegion.compress()
    advanced = MultiResolutionRegion.coarse_run(coarse, 100, per_entity_demand: 0.003)

    assert advanced.summary.available_stock < coarse.summary.available_stock
    assert advanced.summary.consumed_stock > coarse.summary.consumed_stock
    assert_in_delta advanced.summary.total_stock, coarse.summary.total_stock, 1.0e-9
    assert advanced.tick == coarse.tick + 100
  end

  test "external flows are explicit in total stock" do
    coarse = region() |> MultiResolutionRegion.compress()
    advanced = MultiResolutionRegion.coarse_run(coarse, 10, external_inflow: 0.02, external_outflow: 0.005)

    assert_in_delta advanced.summary.total_stock, coarse.summary.total_stock + 0.15, 1.0e-9
  end

  test "refinement is non-unique while preserving aggregate commitments" do
    coarse = region() |> MultiResolutionRegion.compress()
    left = MultiResolutionRegion.refine(coarse, 1)
    right = MultiResolutionRegion.refine(coarse, 99)

    refute left.entities == right.entities
    assert MapSet.size(left.causal_flags) == 2
    assert MapSet.size(right.causal_flags) == 2

    left_summary = MultiResolutionRegion.compress(left).summary
    right_summary = MultiResolutionRegion.compress(right).summary

    for key <- [:population, :available_stock, :held_stock, :consumed_stock, :total_stock, :mean_mobility] do
      assert_in_delta Map.fetch!(left_summary, key), Map.fetch!(right_summary, key), 1.0e-8
      assert_in_delta Map.fetch!(left_summary, key), Map.fetch!(coarse.summary, key), 1.0e-8
    end

    assert left_summary.causal_flags == coarse.summary.causal_flags
    assert right_summary.causal_flags == coarse.summary.causal_flags
    assert left_summary.relation_anchors == coarse.summary.relation_anchors
  end

  test "inert state contains no live microstate but remains refinable" do
    inert = region() |> MultiResolutionRegion.compress() |> MultiResolutionRegion.make_inert()

    assert inert.resolution == :inert
    assert inert.entities == %{}
    assert inert.resources == %{}
    assert inert.social_relations == %{}

    refined = MultiResolutionRegion.refine(inert, 7)
    assert refined.resolution == :live
    assert map_size(refined.entities) == 3
    assert map_size(refined.resources) >= 1
  end

  test "bounded summaries keep only strongest future-relevant social anchors" do
    relations =
      Map.new(1..100, fn index ->
        {{"observer", "actor_#{index}", :context}, %{confidence: index / 100, persistence: index / 50, extreme_imprint: index / 25}}
      end)

    live = %{region() | social_relations: relations}
    coarse = MultiResolutionRegion.compress(live, summary_relation_limit: 8)

    assert length(coarse.summary.relation_anchors) == 8
    assert MultiResolutionRegion.state_cost(coarse) < MultiResolutionRegion.state_cost(live)
  end

  test "coarse scarcity intervention preserves causal direction after refinement" do
    baseline = region() |> MultiResolutionRegion.compress()
    stable = baseline |> MultiResolutionRegion.coarse_run(80, per_entity_demand: 0.002) |> MultiResolutionRegion.refine(17) |> MultiResolutionRegion.compress()
    scarce = baseline |> MultiResolutionRegion.coarse_run(80, per_entity_demand: 0.02) |> MultiResolutionRegion.refine(17) |> MultiResolutionRegion.compress()

    assert scarce.summary.available_stock < stable.summary.available_stock
    assert scarce.summary.consumed_stock > stable.summary.consumed_stock
    assert scarce.summary.mean_energy < stable.summary.mean_energy
  end

  test "invalid resolution transitions are rejected" do
    assert_raise ArgumentError, fn -> region() |> MultiResolutionRegion.refine(1) end
    assert_raise ArgumentError, fn -> region() |> MultiResolutionRegion.make_inert() end
    assert_raise ArgumentError, fn -> region() |> MultiResolutionRegion.coarse_run(1) end
  end
end
