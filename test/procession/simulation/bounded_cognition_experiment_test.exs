defmodule Procession.Simulation.BoundedCognitionExperimentTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.BoundedCognitionExperiment

  test "bounded thought advances world ticks and can change the reactive choice" do
    result = BoundedCognitionExperiment.run(population: 8, ticks: 8, cognitive_budget: 4)

    assert result.summary.world_ticks_advanced == 64
    assert result.summary.mean_work_per_tick <= 4.0
    assert result.summary.mean_operations_per_tick <= 4.0
    assert result.summary.unfinished_after_first_tick_rate > 0.0
    assert result.summary.mean_projected_depth >= 4.0
    assert result.summary.thought_changed_choice_rate == 1.0
    assert result.summary.warm_route_selection_rate == 1.0
  end
end
