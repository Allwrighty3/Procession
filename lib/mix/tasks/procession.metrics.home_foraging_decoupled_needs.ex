defmodule Mix.Tasks.Procession.Metrics.HomeForagingDecoupledNeeds do
  use Mix.Task
  @shortdoc "Runs the decoupled hunger/warmth comparison"
  @impl true
  def run(_args) do
    Procession.Simulation.HomeForagingDecoupledNeedsExperiment.run()
    |> Procession.Simulation.HomeForagingDecoupledNeedsExperiment.report()
    |> Mix.shell().info()
  end
end
