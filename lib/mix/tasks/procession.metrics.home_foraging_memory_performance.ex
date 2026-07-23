defmodule Mix.Tasks.Procession.Metrics.HomeForagingMemoryPerformance do
  use Mix.Task

  @shortdoc "Runs the closed-loop memory performance comparison"

  @impl true
  def run(_args) do
    Procession.Simulation.HomeForagingMemoryPerformanceExperiment.run()
    |> Procession.Simulation.HomeForagingMemoryPerformanceExperiment.report()
    |> Mix.shell().info()
  end
end
