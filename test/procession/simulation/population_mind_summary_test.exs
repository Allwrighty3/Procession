defmodule Procession.Simulation.PopulationMindSummaryTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.PopulationMindSummary

  defp learned_mind(feature, magnitude, seed) do
    loop = DevelopmentalSensorimotorLoop.new(micro_nodes: 64, input_width: 4, seed: seed)

    loop =
      Enum.reduce(1..10, loop, fn tick, current ->
        sensed = DevelopmentalSensorimotorLoop.sense(current, [{:signal, feature, magnitude}], extreme_salience_threshold: 2.0)
        {emitted, _outcome} = DevelopmentalSensorimotorLoop.emit(sensed, tick, output_exploration: 0.0)
        DevelopmentalSensorimotorLoop.feedback(emitted, [feature], 1.0)
      end)

    DevelopmentalMindSnapshot.capture(loop, mind_snapshot_generated_limit: 24)
  end

  test "summary cost is bounded by cohort count rather than population" do
    snapshots =
      for index <- 1..120 do
        feature = if rem(index, 2) == 0, do: :scarcity, else: :shelter
        {"mind_#{index}", learned_mind(feature, 3.0 + rem(index, 3), index)}
      end

    summary = PopulationMindSummary.build(snapshots, population_mind_cohort_limit: 4)

    assert summary.population == 120
    assert length(summary.cohorts) <= 4
    assert PopulationMindSummary.cost(summary) <
             Enum.sum(Enum.map(snapshots, fn {_id, snapshot} -> DevelopmentalMindSnapshot.cost(snapshot) end))
  end

  test "refinement is deterministic for a seed and varies across individuals" do
    summary =
      PopulationMindSummary.build(
        [
          {"a", learned_mind(:scarcity, 5.0, 1)},
          {"b", learned_mind(:shelter, 3.0, 2)},
          {"c", learned_mind(:danger, 7.0, 3)}
        ],
        population_mind_cohort_limit: 3
      )

    ids = ["new_1", "new_2", "new_3"]
    first = PopulationMindSummary.refine(summary, ids, 88)
    second = PopulationMindSummary.refine(summary, ids, 88)

    assert first == second
    assert map_size(first) == 3

    output_masses =
      first
      |> Map.values()
      |> Enum.map(fn snapshot ->
        snapshot
        |> DevelopmentalMindSnapshot.restore()
        |> then(fn loop -> Enum.sum(Map.values(loop.field.output_edges)) end)
      end)

    assert length(Enum.uniq(output_masses)) > 1
  end

  test "refined minds retain structurally valid imprints and motor associations" do
    source = learned_mind(:loss_cue, 8.0, 11)
    summary = PopulationMindSummary.build([{"source", source}], population_mind_cohort_limit: 2)
    %{"refined" => refined} = PopulationMindSummary.refine(summary, ["refined"], 9)
    loop = DevelopmentalMindSnapshot.restore(refined)
    retained = Map.keys(loop.field.sensory.nodes) |> MapSet.new()

    assert map_size(loop.field.salience.imprints) > 0
    assert map_size(loop.field.output_edges) > 0

    assert Enum.all?(loop.field.salience.imprints, fn {node, _value} -> MapSet.member?(retained, node) end)
    assert Enum.all?(loop.field.output_edges, fn {{node, _output}, _value} -> MapSet.member?(retained, node) end)
  end
end