defmodule Procession.Simulation.CognitiveField.LocalFlowTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.LocalFlow

  test "activation moves locally without receiving a desired exit" do
    field =
      CognitiveField.new()
      |> CognitiveField.add_transition(:entry, :middle)
      |> CognitiveField.add_transition(:middle, :exit)

    result =
      LocalFlow.run(field, %{entry: 1.0}, [:exit],
        attenuation: 0.9,
        threshold: 0.01,
        exit_threshold: 0.2
      )

    assert result.winner == :exit
    assert result.ticks >= 2
    assert result.flows[{:entry, :middle}] > 0.0
    assert result.flows[{:middle, :exit}] > 0.0
    assert LocalFlow.dominant_path(result) == [:entry, :middle, :exit]
  end

  test "insufficient activation dissipates before producing an exit" do
    field =
      CognitiveField.new()
      |> CognitiveField.add_transition(:entry, :one)
      |> CognitiveField.add_transition(:one, :two)
      |> CognitiveField.add_transition(:two, :exit)

    result =
      LocalFlow.run(field, %{entry: 0.18}, [:exit],
        attenuation: 0.7,
        threshold: 0.04,
        exit_threshold: 0.15
      )

    assert result.winner == nil
    assert Map.get(result.exit_activation, :exit, 0.0) < 0.15
  end

  test "local resistance divides flow toward the developed branch" do
    field = competing_field()

    trained =
      Enum.reduce(1..35, field, fn _, acc ->
        CognitiveField.traverse(acc, [:entry, :lower, :lower_exit])
      end)

    result =
      LocalFlow.run(trained, %{entry: 1.0}, [:upper_exit, :lower_exit],
        attenuation: 0.9,
        threshold: 0.01,
        exit_threshold: 0.1,
        sharpness: 3.0
      )

    assert result.winner == :lower_exit
    assert result.flows[{:entry, :lower}] > result.flows[{:entry, :upper}]
  end

  test "enacting local flow reinforces the route selected by local dynamics" do
    field = competing_field()

    result =
      LocalFlow.run(field, %{entry: 1.0}, [:upper_exit, :lower_exit],
        attenuation: 0.9,
        threshold: 0.01,
        exit_threshold: 0.1,
        seed: 12
      )

    enacted = LocalFlow.enact(field, result)
    path = LocalFlow.dominant_path(result)
    [from, to | _] = path

    assert CognitiveField.resistance(enacted, from, to) <
             CognitiveField.resistance(field, from, to)
  end

  test "simultaneous entries combine at a shared node" do
    field = recombination_field()

    a_only = recombination_run(field, %{a: 0.55})
    b_only = recombination_run(field, %{b: 0.55})
    combined = recombination_run(field, %{a: 0.35, b: 0.35})

    assert a_only.winner == nil
    assert b_only.winner == nil
    assert combined.winner == :z

    join_activation =
      combined.history
      |> Enum.map(&Map.get(&1, :join, 0.0))
      |> Enum.max()

    assert join_activation > 0.4
  end

  test "learned fragments recombine into an untrained complete trajectory" do
    field = recombination_field()

    training_paths = [
      [:a, :m, :join],
      [:b, :n, :join],
      [:c, :join, :z]
    ]

    trained =
      Enum.reduce(1..30, field, fn _, acc ->
        Enum.reduce(training_paths, acc, &CognitiveField.traverse(&2, &1))
      end)

    result = recombination_run(trained, %{a: 0.35, b: 0.35})
    path = LocalFlow.dominant_path(result)

    assert result.winner == :z
    assert List.last(path) == :z
    refute path in training_paths

    trained_edges =
      training_paths
      |> Enum.flat_map(&Enum.chunk_every(&1, 2, 1, :discard))
      |> Enum.map(&List.to_tuple/1)
      |> MapSet.new()

    assert LocalFlow.novel_flow_fraction(result, trained_edges) == 0.0
  end

  test "local flow differs from globally informed target routing" do
    field = recombination_field()

    assert {:ok, %{path: [:a, :m, :join, :z]}} =
             CognitiveField.propagate(field, :a, :z)

    local = recombination_run(field, %{a: 0.55})
    assert local.winner == nil
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
    |> CognitiveField.add_transition(:c, :join)
    |> CognitiveField.add_transition(:join, :z)
  end

  defp recombination_run(field, activation) do
    LocalFlow.run(field, activation, [:z],
      attenuation: 0.82,
      threshold: 0.03,
      exit_threshold: 0.35,
      max_ticks: 8
    )
  end
end
