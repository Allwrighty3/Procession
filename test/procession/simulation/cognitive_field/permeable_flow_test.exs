defmodule Procession.Simulation.CognitiveField.PermeableFlowTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.FlowLearning
  alias Procession.Simulation.CognitiveField.PermeableFlow

  test "absolute resistance controls transmission through a lone corridor" do
    fresh = line_field()
    trained = Enum.reduce(1..30, fresh, fn _, field -> CognitiveField.traverse(field, [:a, :b]) end)

    fresh_result = PermeableFlow.run(fresh, %{a: 1.0}, [:b], threshold: 0.001)
    trained_result = PermeableFlow.run(trained, %{a: 1.0}, [:b], threshold: 0.001)

    assert trained_result.exit_activation[:b] > fresh_result.exit_activation[:b]
  end

  test "flow conserves activation as exited, remaining, or dissipated energy" do
    result =
      branching_field()
      |> PermeableFlow.run(%{entry: 1.0}, [:upper_exit, :lower_exit],
        threshold: 0.001,
        max_ticks: 2
      )

    assert PermeableFlow.conserved?(result, 1.0e-8)
  end

  test "developed branch receives more flow while absolute loss remains finite" do
    field = branching_field()

    trained =
      Enum.reduce(1..20, field, fn _, acc ->
        CognitiveField.traverse(acc, [:entry, :lower, :lower_exit])
      end)

    result =
      PermeableFlow.run(trained, %{entry: 1.0}, [:upper_exit, :lower_exit],
        threshold: 0.001,
        max_ticks: 3
      )

    assert result.exit_activation[:lower_exit] > result.exit_activation[:upper_exit]
    assert result.dissipated > 0.0
    assert PermeableFlow.conserved?(result, 1.0e-8)
  end

  test "repeated weak rehearsal progressively extends reach along a lone route" do
    field = long_field()
    order = [:a, :b, :c, :d, :exit]

    initial_result = weak_run(field)
    initial_index = reach_index(initial_result, order)

    {trained, reach_history} =
      Enum.reduce(1..80, {field, [initial_index]}, fn _, {acc, history} ->
        result = weak_run(acc)

        updated =
          FlowLearning.apply(acc, result.flows,
            deposit: 0.018,
            decay_slowing: 0.04,
            elapsed: 0.05
          )

        {updated, [reach_index(result, order) | history]}
      end)

    final_result = weak_run(trained)
    final_index = reach_index(final_result, order)

    assert final_index > initial_index
    assert Enum.max(reach_history) >= final_index - 1
    assert PermeableFlow.conserved?(final_result, 1.0e-8)
  end

  test "rehearsal can create later external capability on a route with no alternatives" do
    field = long_field()
    before = external_run(field)

    rehearsed =
      Enum.reduce(1..100, field, fn _, acc ->
        result = weak_run(acc)

        FlowLearning.apply(acc, result.flows,
          deposit: 0.022,
          decay_slowing: 0.04,
          elapsed: 0.04
        )
      end)

    after_rehearsal = external_run(rehearsed)

    assert Map.get(before.exit_activation, :exit, 0.0) == 0.0
    assert Map.get(after_rehearsal.exit_activation, :exit, 0.0) > 0.0
  end

  defp reach_index(result, order) do
    reached = PermeableFlow.furthest_reached(result, order)
    Enum.find_index(order, &(&1 == reached)) || -1
  end

  defp weak_run(field) do
    PermeableFlow.run(field, %{a: 0.25}, [:exit],
      attenuation: 0.97,
      permeability_scale: 0.8,
      threshold: 0.018,
      max_ticks: 6
    )
  end

  defp external_run(field) do
    PermeableFlow.run(field, %{a: 0.40}, [:exit],
      attenuation: 0.97,
      permeability_scale: 0.8,
      threshold: 0.018,
      max_ticks: 6
    )
  end

  defp line_field do
    CognitiveField.new()
    |> CognitiveField.add_transition(:a, :b)
  end

  defp long_field do
    CognitiveField.new()
    |> CognitiveField.add_transition(:a, :b)
    |> CognitiveField.add_transition(:b, :c)
    |> CognitiveField.add_transition(:c, :d)
    |> CognitiveField.add_transition(:d, :exit)
  end

  defp branching_field do
    CognitiveField.new()
    |> CognitiveField.add_transition(:entry, :upper)
    |> CognitiveField.add_transition(:upper, :upper_exit)
    |> CognitiveField.add_transition(:entry, :lower)
    |> CognitiveField.add_transition(:lower, :lower_exit)
  end
end
