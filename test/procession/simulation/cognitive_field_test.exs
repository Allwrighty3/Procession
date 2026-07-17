defmodule Procession.Simulation.CognitiveFieldTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CognitiveField

  test "repeated traversal lowers resistance and slows decay" do
    field = line_field(5)

    {:ok, before} = CognitiveField.propagate(field, 0, 4)

    trained =
      Enum.reduce(1..40, field, fn _, acc ->
        CognitiveField.traverse(acc, before.path)
      end)

    {:ok, after_training} = CognitiveField.propagate(trained, 0, 4)
    transition = CognitiveField.transition(trained, 0, 1)

    assert after_training.resistance < before.resistance
    assert transition.residue > 0.0
    assert transition.decay < transition.baseline_decay
  end

  test "directed traversal does not automatically train the reverse route" do
    field = bidirectional_line_field(5)
    {:ok, forward} = CognitiveField.propagate(field, 0, 4)

    trained =
      Enum.reduce(1..40, field, fn _, acc ->
        CognitiveField.traverse(acc, forward.path)
      end)

    {:ok, trained_forward} = CognitiveField.propagate(trained, 0, 4)
    {:ok, untrained_reverse} = CognitiveField.propagate(trained, 4, 0)

    assert trained_forward.resistance < untrained_reverse.resistance
    assert CognitiveField.resistance(trained, 0, 1) <
             CognitiveField.resistance(trained, 1, 0)
  end

  test "reciprocal traversal produces emergent symmetry" do
    field = bidirectional_line_field(5)
    {:ok, forward} = CognitiveField.propagate(field, 0, 4)
    {:ok, reverse} = CognitiveField.propagate(field, 4, 0)

    trained =
      Enum.reduce(1..40, field, fn _, acc ->
        acc
        |> CognitiveField.traverse(forward.path)
        |> CognitiveField.traverse(reverse.path)
      end)

    assert CognitiveField.symmetry(trained, 0, 1) > 0.95

    {:ok, trained_forward} = CognitiveField.propagate(trained, 0, 4)
    {:ok, trained_reverse} = CognitiveField.propagate(trained, 4, 0)

    assert_in_delta trained_forward.resistance, trained_reverse.resistance, 0.25
  end

  test "rehearsal creates a weaker proto-path than enacted traversal" do
    field = line_field(5)
    {:ok, route} = CognitiveField.propagate(field, 0, 4)

    rehearsed =
      Enum.reduce(1..20, field, fn _, acc ->
        CognitiveField.rehearse(acc, route.path)
      end)

    enacted =
      Enum.reduce(1..20, field, fn _, acc ->
        CognitiveField.traverse(acc, route.path)
      end)

    {:ok, rehearsed_route} = CognitiveField.propagate(rehearsed, 0, 4)
    {:ok, enacted_route} = CognitiveField.propagate(enacted, 0, 4)

    assert rehearsed_route.resistance < route.resistance
    assert enacted_route.resistance < rehearsed_route.resistance
  end

  test "unused residue decays without resetting immediately" do
    field = line_field(3)
    {:ok, route} = CognitiveField.propagate(field, 0, 2)

    trained =
      Enum.reduce(1..30, field, fn _, acc ->
        CognitiveField.traverse(acc, route.path)
      end)

    before_idle = CognitiveField.transition(trained, 0, 1).residue
    rested = CognitiveField.idle(trained, 20)
    after_idle = CognitiveField.transition(rested, 0, 1).residue

    assert after_idle < before_idle
    assert after_idle > 0.0
  end

  test "least-resistance propagation changes after a competing route is traversed" do
    field =
      CognitiveField.new()
      |> CognitiveField.add_transition(:a, :upper)
      |> CognitiveField.add_transition(:upper, :b)
      |> CognitiveField.add_transition(:a, :lower)
      |> CognitiveField.add_transition(:lower, :b)

    trained =
      Enum.reduce(1..30, field, fn _, acc ->
        CognitiveField.traverse(acc, [:a, :lower, :b])
      end)

    assert {:ok, %{path: [:a, :lower, :b]}} =
             CognitiveField.propagate(trained, :a, :b)
  end

  defp line_field(size) do
    Enum.reduce(0..(size - 2), CognitiveField.new(), fn node, field ->
      CognitiveField.add_transition(field, node, node + 1)
    end)
  end

  defp bidirectional_line_field(size) do
    Enum.reduce(0..(size - 2), CognitiveField.new(), fn node, field ->
      field
      |> CognitiveField.add_transition(node, node + 1)
      |> CognitiveField.add_transition(node + 1, node)
    end)
  end
end
