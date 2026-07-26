defmodule Procession.Simulation.CoarseLocomotionDecisionTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CoarseLocomotionDecision

  test "observed displacement selects only a matching perceived exit" do
    exits = [
      %{direction: :north, region_id: "ridge", segment_extent: 3},
      %{direction: :east, region_id: "river", segment_extent: 5, route_opts: [travel_demand: 0.02]}
    ]

    outcome = %{
      displaced?: true,
      direction: :east,
      pattern: {:m2, :m6},
      consequence: :displacement
    }

    assert {:ok, decision} = CoarseLocomotionDecision.from_motor_outcome(outcome, exits)
    assert decision.action == :continue
    assert decision.to_region == "river"
    assert decision.segment_extent == 5
    assert decision.route_opts == [travel_demand: 0.02]
    assert decision.observed_direction == :east
    assert decision.motor_pattern == {:m2, :m6}
    assert decision.source == :motor_consequence
    assert :ok = CoarseLocomotionDecision.validate(decision)
  end

  test "motor output with no matching perceived exit remains without inventing a destination" do
    exits = [%{direction: :north, region_id: "ridge", segment_extent: 3}]
    outcome = %{displaced?: true, direction: :west, consequence: :displacement}

    assert {:ok, decision} = CoarseLocomotionDecision.from_motor_outcome(outcome, exits)
    assert decision.action == :remain
    assert decision.reason == :no_perceived_exit_in_observed_direction
    refute Map.has_key?(decision, :to_region)
  end

  test "failed or resisted motor output remains rather than ending the episode" do
    outcome = %{
      displaced?: false,
      blocked?: true,
      direction: :east,
      consequence: :resisted_displacement
    }

    assert {:ok, decision} = CoarseLocomotionDecision.from_motor_outcome(outcome, [])
    assert decision.action == :remain
    assert decision.reason == :resisted_displacement
    refute decision.action == :stop
  end

  test "ambiguous exits in one observed direction are rejected" do
    exits = [
      %{direction: :south, region_id: "marsh_a", segment_extent: 2},
      %{direction: :south, region_id: "marsh_b", segment_extent: 4}
    ]

    assert {:error, {:ambiguous_perceived_exit_direction, :south}} =
             CoarseLocomotionDecision.from_motor_outcome(
               %{displaced?: true, direction: :south},
               exits
             )
  end

  test "only explicit behavioral data can stop an episode" do
    assert :ok =
             CoarseLocomotionDecision.validate(%{
               action: :stop,
               reason: :chose_to_remain_here,
               source: :behavior_output
             })

    assert {:error, {:unexpected_locomotion_field, :to_region}} =
             CoarseLocomotionDecision.validate(%{
               action: :stop,
               to_region: "hidden_goal"
             })
  end

  test "continue decisions require bounded physical segment data" do
    assert {:error, {:missing_locomotion_field, :to_region}} =
             CoarseLocomotionDecision.validate(%{action: :continue, segment_extent: 2})

    assert {:error, {:invalid_locomotion_field, :segment_extent}} =
             CoarseLocomotionDecision.validate(%{
               action: :continue,
               to_region: "ridge",
               segment_extent: 0
             })
  end
end
