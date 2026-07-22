defmodule Procession.Simulation.HomeForagingDecoupledNeedsExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.HomeForagingDecoupledNeedsExperiment, as: Experiment

  test "reports continuous hunger and warmth metrics" do
    result = Experiment.run(population: 2, teaching_ticks: 80, withdrawal_ticks: 80)
    assert result.population == 2
    for condition <- [:coupled_baseline, :decoupled, :decoupled_stagnation] do
      summary = result.summary[condition]
      assert is_float(summary.hunger)
      assert is_float(summary.warmth)
      assert is_float(summary.hunger_relief)
      assert is_float(summary.warmth_relief)
    end
  end
end
