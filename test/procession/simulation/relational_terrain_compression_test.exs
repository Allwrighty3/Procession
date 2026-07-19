defmodule Procession.Simulation.RelationalTerrainCompressionTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationalTerrain
  alias Procession.Simulation.RelationalTerrainCompression

  @opts [dimensions: 8, deformation_rate: 0.18, reverse_deformation_ratio: 0.10,
    auto_expand_dimensions: false, reuse_radius: 0.001, encoding_salt: :compression_test]

  test "extended practice produces larger candidate assemblies and greater compression" do
    route = Enum.map(1..64, &{:step, &1})

    shallow = route |> train(1) |> RelationalTerrainCompression.analyze(route)
    practiced = route |> train(20) |> RelationalTerrainCompression.analyze(route)
    overlearned = route |> train(100) |> RelationalTerrainCompression.analyze(route)

    assert shallow.transitions_saved < practiced.transitions_saved
    assert practiced.transitions_saved <= overlearned.transitions_saved
    assert largest(practiced) < largest(overlearned)
    assert overlearned.compression_ratio < practiced.compression_ratio
    assert overlearned.compressed_members <= length(route)
  end

  test "a disturbance reopens local detail without destroying other assemblies" do
    route = Enum.map(1..64, &{:step, &1})
    terrain = train(route, 100)

    stable = RelationalTerrainCompression.analyze(terrain, route)
    disturbed = RelationalTerrainCompression.analyze(terrain, route, disturbances: [{:step, 33}])

    refute Enum.any?(disturbed.assemblies, &({:step, 33} in &1.members))
    assert disturbed.transitions_saved < stable.transitions_saved
    assert disturbed.assembly_count > 0
    assert Enum.any?(disturbed.assemblies, &({:step, 1} in &1.members))
    assert Enum.any?(disturbed.assemblies, &({:step, 64} in &1.members))
  end

  test "weak or ambiguous relationships remain detailed" do
    route = Enum.map(1..16, &{:step, &1})
    terrain = train(route, 1)

    result = RelationalTerrainCompression.analyze(terrain, route, min_support: 1.0)

    assert result.assemblies == []
    assert result.transitions_saved == 0
    assert result.compressed_transitions == result.detailed_transitions
  end

  defp largest(%{assemblies: []}), do: 0
  defp largest(result), do: result.assemblies |> Enum.map(&length(&1.members)) |> Enum.max()

  defp train(route, repetitions) do
    Enum.reduce(1..repetitions, RelationalTerrain.new(@opts), fn _, terrain ->
      terrain = RelationalTerrain.clear_activity(terrain)
      Enum.reduce(route, terrain, &RelationalTerrain.observe(&2, &1, @opts))
    end)
  end
end
