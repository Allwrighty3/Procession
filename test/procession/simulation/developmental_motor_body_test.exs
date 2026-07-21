defmodule Procession.Simulation.DevelopmentalMotorBodyTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalMotorBody, as: Body

  test "body exposes low-level channels and patterns rather than mature actions" do
    assert Body.channels() == [:m1, :m2, :m3, :m4, :m5, :m6, :m7, :m8]
    assert length(Body.patterns()) == 28
    refute Enum.any?(Body.patterns(), &(&1 in [:north, :south, :east, :west, :manipulate]))
  end

  test "new body begins with no stable coordinated pattern" do
    body = Body.new()

    assert Body.stable_pattern_count(body) == 0
    assert Enum.all?(Body.strongest_patterns(body, 28), fn {_pattern, strength} ->
             strength < 0.03
           end)
  end

  test "repeated supported consequences stabilize a learner-owned pattern" do
    body = Body.new()
    pattern = hd(Body.patterns())

    trained =
      Enum.reduce(1..30, body, fn _, current ->
        Body.supported_attempt(current, pattern, :east, 1.0)
      end)

    [{^pattern, strength} | _] = Body.strongest_patterns(trained, 1)
    assert strength >= 0.30
    assert Body.stable_pattern_count(trained) >= 1
  end

  test "unsupported early activation usually produces no displacement" do
    body = Body.new()
    pattern = hd(Body.patterns())

    {_body, outcomes} =
      Enum.reduce(1..20, {body, []}, fn tick, {current, outcomes} ->
        {next, outcome} = Body.attempt(current, pattern, {1, 1}, tick, seed: 37, bounds: {3, 3})
        {next, [outcome | outcomes]}
      end)

    assert Enum.count(outcomes, & &1.displaced?) < 10
  end
end
