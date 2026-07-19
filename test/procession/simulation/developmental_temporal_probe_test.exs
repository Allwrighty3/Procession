defmodule Procession.Simulation.DevelopmentalTemporalProbeTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalTemporalProbe

  test "reports order sensitivity across multiple developmental horizons" do
    result = DevelopmentalTemporalProbe.run(horizons: [96, 192], stage_cycles: 12, seed: 7)

    assert Map.keys(result.horizons) |> Enum.sort() == [96, 192]

    Enum.each(result.horizons, fn {_ticks, horizon} ->
      assert horizon.baseline.generated >= 0
      assert horizon.baseline.generated_relations >= 0

      Enum.each([horizon.reversed, horizon.rotated, horizon.block_reversed], fn comparison ->
        assert comparison.support_similarity >= 0.0
        assert comparison.support_similarity <= 1.0
        assert comparison.edge_similarity >= 0.0
        assert comparison.edge_similarity <= 1.0
        assert comparison.edge_weight_similarity >= 0.0
        assert comparison.edge_weight_similarity <= 1.0
        assert comparison.generated_relations >= 0
      end)
    end)
  end

  test "staged histories preserve the same observational contract" do
    result = DevelopmentalTemporalProbe.run(horizons: [96], stage_cycles: 10, seed: 3)

    assert result.staged.forward_then_reverse.generated >= 0
    assert result.staged.reverse_then_forward.generated >= 0
    assert result.staged.forward_then_reverse.generated_relations >= 0
    assert result.staged.reverse_then_forward.generated_relations >= 0
    assert result.staged.similarity.generated_relations >= 0
    assert is_binary(DevelopmentalTemporalProbe.report(result))
  end
end
