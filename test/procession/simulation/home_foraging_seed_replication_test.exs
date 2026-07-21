defmodule Procession.Simulation.HomeForagingSeedReplicationTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.HomeForagingSeedReplication

  test "aggregates disjoint seeds and exposes diagnostic comparisons" do
    result =
      HomeForagingSeedReplication.run(
        population: 2,
        seeds: [101, 211],
        slow_stage_ticks: 8,
        slow_withdrawal_ticks: 12,
        standard_stage_ticks: 4,
        standard_withdrawal_ticks: 6
      )

    assert result.seeds == [101, 211]
    assert result.total_per_condition == 4

    for condition <- [:abrupt_assistance, :staged_assistance] do
      assert result.summary[condition].population == 4
      assert is_number(result.diagnostics[condition].corr_context)
      assert result.diagnostics[condition].seed_consumed_min <=
               result.diagnostics[condition].seed_consumed_max
    end
  end
end
