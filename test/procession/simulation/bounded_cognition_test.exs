defmodule Procession.Simulation.BoundedCognitionTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.BoundedCognition

  test "positive-cost thought cannot consume an unbounded number of operations in one tick" do
    step = fn continuation, _remaining ->
      n = continuation || 0
      {:continue, {:project, 1, {:step, n}}, n + 1}
    end

    state = BoundedCognition.new(0) |> BoundedCognition.run_tick(step, cognitive_budget: 7)

    assert state.last_tick_work == 7
    assert state.last_tick_operations == 7
    assert state.continuation == 7
    assert state.intended_action == nil
  end

  test "unfinished thought continues on a later external tick" do
    step = fn
      n, _remaining when n < 5 -> {:continue, {:project, 2, n}, n + 1}
      n, _remaining -> {:commit, :move_homeward, n}
    end

    first = BoundedCognition.new(0) |> BoundedCognition.run_tick(step, cognitive_budget: 4)
    assert first.continuation == 2
    assert first.intended_action == nil

    second = BoundedCognition.run_tick(first, step, cognitive_budget: 8)
    assert second.continuation == 5
    assert second.intended_action == :move_homeward
  end

  test "decision influence records when thought changes the baseline physical action" do
    step = fn continuation, _remaining -> {:commit, :return_home, continuation} end

    state =
      BoundedCognition.new(:ready, baseline_action: :remain_near_food)
      |> BoundedCognition.run_tick(step, cognitive_budget: 3)

    assert state.decision_influence == 1
  end

  test "zero-cost thought is rejected" do
    step = fn continuation, _remaining ->
      {:continue, {:compare, 0, :free_loop}, continuation}
    end

    assert_raise ArgumentError, ~r/positive integer cost/, fn ->
      BoundedCognition.new(:loop) |> BoundedCognition.run_tick(step, cognitive_budget: 10)
    end
  end
end
