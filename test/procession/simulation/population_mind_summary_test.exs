defmodule Procession.Simulation.PopulationMindSummaryTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.PopulationMindSummary

  defp learned_mind(feature, magnitude, seed, coherence \\ 1.0) do
    loop = DevelopmentalSensorimotorLoop.new(micro_nodes: 64, input_width: 4, seed: seed)

    loop =
      Enum.reduce(1..10, loop, fn tick, current ->
        sensed =
          DevelopmentalSensorimotorLoop.sense(
            current,
            [{:signal, feature, magnitude}],
            extreme_salience_threshold: 2.0
          )

        {emitted, _outcome} =
          DevelopmentalSensorimotorLoop.emit(sensed, tick,
            output_exploration: 0.0,
            seed: seed
          )

        DevelopmentalSensorimotorLoop.feedback(emitted, [feature], coherence)
      end)

    DevelopmentalMindSnapshot.capture(loop, mind_snapshot_generated_limit: 24)
  end

  test "summary cost is bounded by cohort count rather than population" do
    snapshots =
      for index <- 1..120 do
        feature = if rem(index, 2) == 0, do: :scarcity, else: :shelter
        learned_mind(feature, 3.0 + rem(index, 3), index)
      end

    summary = PopulationMindSummary.capture(snapshots, 120, population_mind_cohort_limit: 4)

    assert summary.total_population == 120
    assert summary.minded_population == 120
    assert length(summary.cohorts) <= 4

    assert PopulationMindSummary.cost(summary) <
             Enum.sum(Enum.map(snapshots, &DevelopmentalMindSnapshot.cost/1))
  end

  test "refinement is deterministic for a seed and varies across individuals" do
    summary =
      PopulationMindSummary.capture(
        [
          learned_mind(:scarcity, 5.0, 1),
          learned_mind(:shelter, 3.0, 2),
          learned_mind(:danger, 7.0, 3)
        ],
        3,
        population_mind_cohort_limit: 3
      )

    first = for ordinal <- 1..3, do: PopulationMindSummary.instantiate(summary, 88, ordinal)
    second = for ordinal <- 1..3, do: PopulationMindSummary.instantiate(summary, 88, ordinal)

    assert first == second
    assert Enum.all?(first, &match?({:ok, _snapshot}, &1))

    output_masses =
      Enum.map(first, fn {:ok, snapshot} ->
        snapshot
        |> DevelopmentalMindSnapshot.restore()
        |> then(fn loop -> Enum.sum(Map.values(loop.field.output_edges)) end)
      end)

    assert length(Enum.uniq(output_masses)) > 1
  end

  test "mind prevalence is retained without storing one snapshot per resident" do
    summary =
      PopulationMindSummary.capture(
        [learned_mind(:scarcity, 4.0, 1), learned_mind(:shelter, 4.0, 2)],
        10,
        population_mind_cohort_limit: 2
      )

    reconstructed = for ordinal <- 1..1_000, do: PopulationMindSummary.instantiate(summary, 44, ordinal)
    minded = Enum.count(reconstructed, &match?({:ok, _}, &1))

    assert minded in 160..240
    assert length(summary.cohorts) <= 2
  end

  test "rare high-impact cohorts survive beside common ordinary cohorts" do
    ordinary = for seed <- 1..20, do: learned_mind(:routine, 1.0, seed)
    severe = learned_mind(:loss_cue, 9.0, 999)

    summary =
      PopulationMindSummary.capture(ordinary ++ [severe], 21,
        population_mind_cohort_limit: 2
      )

    assert length(summary.cohorts) == 2

    assert Enum.any?(summary.cohorts, fn cohort ->
             loop = DevelopmentalMindSnapshot.restore(cohort.prototype)
             map_size(loop.field.salience.imprints) > 0
           end)
  end

  test "structurally different learned motor tendencies do not collapse by equal mass" do
    east = learned_mind(:east_context, 4.0, 21)
    west = learned_mind(:west_context, 4.0, 22)

    summary = PopulationMindSummary.capture([east, west], 2, population_mind_cohort_limit: 2)

    assert length(summary.cohorts) == 2
    assert summary.cohorts |> Enum.map(& &1.signature) |> Enum.uniq() |> length() == 2
  end

  test "refined minds retain structurally valid imprints and motor associations" do
    source = learned_mind(:loss_cue, 8.0, 11)
    summary = PopulationMindSummary.capture([source], 1, population_mind_cohort_limit: 2)
    assert {:ok, refined} = PopulationMindSummary.instantiate(summary, 9, 1)

    loop = DevelopmentalMindSnapshot.restore(refined)
    retained = Map.keys(loop.field.sensory.nodes) |> MapSet.new()

    assert map_size(loop.field.salience.imprints) > 0
    assert map_size(loop.field.output_edges) > 0

    assert Enum.all?(loop.field.salience.imprints, fn {node, _value} ->
             MapSet.member?(retained, node)
           end)

    assert Enum.all?(loop.field.output_edges, fn {{node, _output}, _value} ->
             MapSet.member?(retained, node)
           end)
  end
end
