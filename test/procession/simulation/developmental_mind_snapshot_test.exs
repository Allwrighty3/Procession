defmodule Procession.Simulation.DevelopmentalMindSnapshotTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalMindSnapshot
  alias Procession.Simulation.DevelopmentalMotorBody
  alias Procession.Simulation.DevelopmentalSensorimotorField
  alias Procession.Simulation.DevelopmentalSensorimotorLoop

  defp trained_loop do
    opts = [
      micro_nodes: 64,
      input_width: 5,
      seed: 17,
      output_exploration: 0.0,
      consolidation_threshold: 2,
      minimum_compression_gain: -100.0,
      extreme_salience_threshold: 3.0
    ]

    Enum.reduce(1..180, DevelopmentalSensorimotorLoop.new(opts), fn tick, loop ->
      feature = {:context, rem(tick, 24)}
      magnitude = if tick in [40, 90, 140], do: 8.0, else: 1.0
      sensed = DevelopmentalSensorimotorLoop.sense(loop, [{:signal, feature, magnitude}], opts)
      {emitted, _outcome} = DevelopmentalSensorimotorLoop.emit(sensed, tick, opts)
      DevelopmentalSensorimotorLoop.feedback(emitted, [feature], 0.8, opts)
    end)
  end

  test "snapshot is bounded and removes diagnostic history" do
    loop = trained_loop()

    snapshot =
      DevelopmentalMindSnapshot.capture(loop,
        mind_snapshot_generated_limit: 12,
        mind_snapshot_edge_limit: 40,
        mind_snapshot_output_limit: 24,
        mind_snapshot_exposure_limit: 10,
        mind_snapshot_history_limit: 3
      )

    restored = DevelopmentalMindSnapshot.restore(snapshot)

    assert MapSet.size(restored.field.sensory.generated) <= 12
    assert map_size(restored.field.sensory.edges) <= 40
    assert map_size(restored.field.output_edges) <= 24
    assert map_size(restored.field.salience.exposure) <= 10
    assert length(restored.field.sensory.history) <= 3
    assert DevelopmentalMindSnapshot.cost(snapshot) < term_cost(loop)
  end

  test "all retained structures reference retained nodes" do
    snapshot = DevelopmentalMindSnapshot.capture(trained_loop(), mind_snapshot_generated_limit: 8)
    loop = DevelopmentalMindSnapshot.restore(snapshot)
    retained = loop.field.sensory.nodes |> Map.keys() |> MapSet.new()

    assert Enum.all?(loop.field.sensory.edges, fn {{from, to}, _} ->
             MapSet.member?(retained, from) and MapSet.member?(retained, to)
           end)

    assert Enum.all?(loop.field.output_edges, fn {{source, _output}, _} ->
             MapSet.member?(retained, source)
           end)

    assert Enum.all?(loop.field.salience.imprints, fn {node, _} ->
             MapSet.member?(retained, node)
           end)

    assert Enum.all?(loop.field.sensory.nodes, fn {_id, node} ->
             MapSet.subset?(node.support, retained)
           end)
  end

  test "extreme imprints and learned motor support survive restoration" do
    loop = trained_loop()
    before_imprints = map_size(loop.field.salience.imprints)
    before_outputs = map_size(loop.field.output_edges)

    restored =
      loop
      |> DevelopmentalSensorimotorLoop.snapshot(
        mind_snapshot_generated_limit: 64,
        mind_snapshot_edge_limit: 512,
        mind_snapshot_output_limit: 256
      )
      |> DevelopmentalMindSnapshot.restore()

    assert before_imprints > 0
    assert before_outputs > 0
    assert map_size(restored.field.salience.imprints) > 0
    assert map_size(restored.field.output_edges) > 0
    assert restored.pending_output == nil
  end

  test "restored loop continues monotonically and retains compatible output preference" do
    loop = trained_loop()
    snapshot = DevelopmentalSensorimotorLoop.snapshot(loop, mind_snapshot_generated_limit: 64)
    restored = DevelopmentalSensorimotorLoop.new(snapshot: snapshot)
    next_tick = loop.last_tick + 1
    feature = {:context, rem(next_tick, 24)}

    before_scores = DevelopmentalSensorimotorField.output_scores(loop.field, DevelopmentalMotorBody.patterns(), loop.config)
    after_scores = DevelopmentalSensorimotorField.output_scores(restored.field, DevelopmentalMotorBody.patterns(), restored.config)

    assert best_pattern(before_scores) == best_pattern(after_scores)

    sensed = DevelopmentalSensorimotorLoop.sense(restored, [feature])
    {continued, _} = DevelopmentalSensorimotorLoop.emit(sensed, next_tick)
    assert continued.last_tick == next_tick
    assert continued.cycles == loop.cycles + 1
  end

  test "unsupported versions are rejected" do
    assert_raise ArgumentError, ~r/unsupported mind snapshot version/, fn ->
      DevelopmentalMindSnapshot.restore(%{version: 999, loop: nil})
    end
  end

  defp best_pattern(scores), do: scores |> Enum.max_by(fn {pattern, score} -> {score, pattern} end) |> elem(0)
  defp term_cost(term), do: term |> :erlang.term_to_binary() |> byte_size()
end
