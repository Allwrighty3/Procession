defmodule Procession.Simulation.CognitiveFieldPropagationTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.{CognitiveField, CognitiveFieldExperiment}
  alias CognitiveField.Trajectory

  test "autonomous propagation chooses among exits without receiving a target" do
    field = competing_field()

    trained =
      Enum.reduce(1..35, field, fn _, acc ->
        CognitiveField.traverse(acc, [:entry, :lower, :lower_exit])
      end)

    assert {:ok, %Trajectory{} = trajectory} =
             CognitiveField.propagate(trained, :entry,
               exits: [:upper_exit, :lower_exit],
               temperature: 0.05,
               seed: 7
             )

    assert trajectory.exit == :lower_exit
    assert trajectory.path == [:entry, :lower, :lower_exit]
    assert Enum.map(trajectory.candidates, & &1.exit) |> Enum.sort() ==
             [:lower_exit, :upper_exit]
  end

  test "temporary activation can change which equally available route wins" do
    field = competing_field()

    assert {:ok, trajectory} =
             CognitiveField.propagate(field, :entry,
               exits: [:upper_exit, :lower_exit],
               activation: %{lower: 5.0},
               activation_bias: 0.18,
               temperature: 0.05,
               seed: 11
             )

    assert trajectory.exit == :lower_exit
  end

  test "the same field and seed replay the same competition" do
    field = competing_field()
    opts = [exits: [:upper_exit, :lower_exit], temperature: 0.8, seed: 91]

    assert {:ok, first} = CognitiveField.propagate(field, :entry, opts)
    assert {:ok, second} = CognitiveField.propagate(field, :entry, opts)

    assert first.exit == second.exit
    assert first.path == second.path
    assert first.resistance == second.resistance
  end

  test "enacting the selected trajectory changes later autonomous choice" do
    field = competing_field()

    assert {:ok, trajectory} =
             CognitiveField.propagate(field, :entry,
               exits: [:upper_exit, :lower_exit],
               activation: %{lower: 5.0},
               activation_bias: 0.18,
               temperature: 0.05,
               seed: 2
             )

    enacted =
      Enum.reduce(1..25, field, fn _, acc ->
        CognitiveField.enact(acc, trajectory)
      end)

    assert CognitiveField.resistance(enacted, :entry, :lower) <
             CognitiveField.resistance(enacted, :entry, :upper)

    assert {:ok, later} =
             CognitiveField.propagate(enacted, :entry,
               exits: [:upper_exit, :lower_exit],
               temperature: 0.05,
               seed: 999
             )

    assert later.exit == trajectory.exit
  end

  test "terminal contradiction disturbs the failed continuation but preserves shared traversal" do
    field =
      CognitiveField.new()
      |> CognitiveField.add_transition(:entry, :shared)
      |> CognitiveField.add_transition(:shared, :exit)

    trained =
      Enum.reduce(1..30, field, fn _, acc ->
        CognitiveField.traverse(acc, [:entry, :shared, :exit])
      end)

    trajectory = %Trajectory{
      entry: :entry,
      exit: :exit,
      path: [:entry, :shared, :exit],
      resistance: 0.0,
      candidates: [],
      seed: 0
    }

    shared_before = CognitiveField.transition(trained, :entry, :shared).residue
    terminal_before = CognitiveField.transition(trained, :shared, :exit).residue

    disturbed =
      CognitiveField.disturb_terminal(trained, trajectory,
        magnitude: 0.20,
        fraction: 0.40
      )

    assert CognitiveField.transition(disturbed, :entry, :shared).residue == shared_before
    assert CognitiveField.transition(disturbed, :shared, :exit).residue < terminal_before
  end

  test "closed-loop continuation makes a coherent exit increasingly dominant" do
    field = competing_field()

    episodes =
      Enum.map(1..80, fn _ ->
        %{
          entry: :entry,
          exits: [:upper_exit, :lower_exit],
          continuation: fn trajectory ->
            if trajectory.exit == :lower_exit do
              :coherent
            else
              {:contradiction, [magnitude: 0.10, fraction: 0.50]}
            end
          end,
          opts: [temperature: 0.45]
        }
      end)

    assert {:ok, result} = CognitiveFieldExperiment.run(field, episodes)

    exits =
      1..50
      |> Enum.map(fn seed ->
        {:ok, trajectory} =
          CognitiveField.propagate(result.field, :entry,
            exits: [:upper_exit, :lower_exit],
            temperature: 0.20,
            seed: seed
          )

        trajectory.exit
      end)
      |> Enum.frequencies()

    assert Map.get(exits, :lower_exit, 0) > Map.get(exits, :upper_exit, 0)

    summary = CognitiveFieldExperiment.summarize(result.episodes)
    assert summary.episodes == 80
    assert summary.continuations[:coherent] > 0
    assert summary.continuations[:contradiction] > 0
  end

  test "trajectory overlap reports shared directed structure" do
    first = %Trajectory{
      entry: :a,
      exit: :d,
      path: [:a, :b, :c, :d],
      resistance: 3.0,
      candidates: [],
      seed: 1
    }

    second = %Trajectory{
      entry: :a,
      exit: :e,
      path: [:a, :b, :c, :e],
      resistance: 3.0,
      candidates: [],
      seed: 2
    }

    assert_in_delta CognitiveField.trajectory_overlap(first, second), 0.5, 0.0001
  end

  defp competing_field do
    CognitiveField.new()
    |> CognitiveField.add_transition(:entry, :upper)
    |> CognitiveField.add_transition(:upper, :upper_exit)
    |> CognitiveField.add_transition(:entry, :lower)
    |> CognitiveField.add_transition(:lower, :lower_exit)
  end
end
