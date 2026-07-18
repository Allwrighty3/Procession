defmodule Procession.Simulation.CognitiveField.InternalFlowTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.FlowLearning
  alias Procession.Simulation.CognitiveField.InternalFlow
  alias Procession.Simulation.CognitiveField.LocalFlow

  test "partial internal flow dissipates before an exit while still shaping traversed edges" do
    field = line_field()

    %{field: rehearsed, result: result} =
      InternalFlow.rehearse(field, %{entry: 0.30}, [:exit], max_ticks: 2)

    assert result.winner == nil
    assert Map.get(result.flows, {:entry, :one}, 0.0) > 0.0
    assert CognitiveField.resistance(rehearsed, :entry, :one) <
             CognitiveField.resistance(field, :entry, :one)
  end

  test "internal rehearsal biases a developed route less than enacted flow" do
    field = competing_field()
    primed = CognitiveField.traverse(field, [:entry, :upper, :upper_exit])

    internally_rehearsed =
      Enum.reduce(1..12, primed, fn _, acc ->
        InternalFlow.rehearse(acc, %{entry: 0.40}, [:upper_exit, :lower_exit],
          exit_threshold: 0.60
        ).field
      end)

    physical_result =
      LocalFlow.run(primed, %{entry: 1.0}, [:upper_exit, :lower_exit],
        attenuation: 0.9,
        threshold: 0.01,
        exit_threshold: 0.1,
        sharpness: 3.0
      )

    physically_enacted =
      FlowLearning.apply(primed, physical_result.flows,
        deposit: 0.09,
        decay_slowing: 0.13
      )

    internal_gap = route_gap(internally_rehearsed)
    physical_gap = route_gap(physically_enacted)

    assert internal_gap > route_gap(primed)
    assert physical_gap > internal_gap
  end

  test "repeated internal coactivation prepares a recombined route for later external flow" do
    field = recombination_field()

    baseline = external_recombination(field)

    rehearsed =
      Enum.reduce(1..20, field, fn _, acc ->
        InternalFlow.rehearse(acc, %{a: 0.24, b: 0.24}, [:z],
          max_ticks: 3,
          exit_threshold: 0.80
        ).field
      end)

    after_rehearsal = external_recombination(rehearsed)

    assert baseline.winner == nil
    assert Map.get(after_rehearsal.exit_activation, :z, 0.0) >
             Map.get(baseline.exit_activation, :z, 0.0)
  end

  defp route_gap(field) do
    CognitiveField.resistance(field, :entry, :lower) -
      CognitiveField.resistance(field, :entry, :upper)
  end

  defp line_field do
    CognitiveField.new()
    |> CognitiveField.add_transition(:entry, :one)
    |> CognitiveField.add_transition(:one, :two)
    |> CognitiveField.add_transition(:two, :exit)
  end

  defp competing_field do
    CognitiveField.new()
    |> CognitiveField.add_transition(:entry, :upper)
    |> CognitiveField.add_transition(:upper, :upper_exit)
    |> CognitiveField.add_transition(:entry, :lower)
    |> CognitiveField.add_transition(:lower, :lower_exit)
  end

  defp recombination_field do
    CognitiveField.new()
    |> CognitiveField.add_transition(:a, :m)
    |> CognitiveField.add_transition(:m, :join)
    |> CognitiveField.add_transition(:b, :n)
    |> CognitiveField.add_transition(:n, :join)
    |> CognitiveField.add_transition(:join, :z)
  end

  defp external_recombination(field) do
    LocalFlow.run(field, %{a: 0.32, b: 0.32}, [:z],
      attenuation: 0.82,
      threshold: 0.03,
      exit_threshold: 0.36,
      max_ticks: 8
    )
  end
end
