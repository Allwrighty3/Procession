defmodule Procession.Simulation.HomeForagingContingencyExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.HomeForagingContingencyExperiment
  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  test "negative transition coherence weakens output support without changing sensation" do
    opts = [micro_nodes: 32, input_width: 2, output_plasticity_budget: 0.2]
    field = Field.new(opts) |> Field.sense([{:vision, :food_direction, :east}], opts)
    learned = Enum.reduce(1..10, field, fn _, f -> Field.record_output(f, :east, 1.0, opts) end)
    before = Field.output_score(learned, :east, opts)
    sensory = learned.sensory
    weakened = Enum.reduce(1..10, learned, fn _, f -> Field.record_output(f, :east, -1.0, opts) end)

    assert Field.output_score(weakened, :east, opts) < before
    assert weakened.sensory == sensory
  end

  test "runs standard, slow, and ultra-slow long-lived variants" do
    result = HomeForagingContingencyExperiment.run(
      population: 2,
      standard_stage_ticks: 3,
      standard_withdrawal_ticks: 4,
      slow_stage_ticks: 6,
      slow_withdrawal_ticks: 8,
      ultra_stage_ticks: 9,
      ultra_withdrawal_ticks: 12,
      seed: 1
    )

    for variant <- [:standard, :slow_long_lived, :ultra_slow_long_lived] do
      summary = result.summary[{variant, :staged_assistance}]
      assert summary
      assert is_number(summary.cycles)
      assert is_number(summary.action_entropy)
      assert is_number(summary.context_drift)
      assert summary.ticks > 0
    end
  end
end
