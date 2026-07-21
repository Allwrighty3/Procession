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

    assert Map.has_key?(result.summary, {:standard, :staged_assistance})
    assert Map.has_key?(result.summary, {:slow_long_lived, :staged_assistance})
    assert Map.has_key?(result.summary, {:ultra_slow_long_lived, :staged_assistance})

    assert result.summary[{:slow_long_lived, :staged_assistance}].ticks >=
             result.summary[{:standard, :staged_assistance}].ticks

    assert result.summary[{:ultra_slow_long_lived, :staged_assistance}].ticks >=
             result.summary[{:slow_long_lived, :staged_assistance}].ticks
  end
end
