defmodule Mix.Tasks.Procession.Metrics.RecursiveMemoryQuality do
  use Mix.Task

  @shortdoc "Runs the recursive memory compression-quality audit"

  @impl true
  def run(_args) do
    Procession.Simulation.RecursiveMemoryQualityExperiment.run()
    |> Procession.Simulation.RecursiveMemoryQualityExperiment.report()
    |> Mix.shell().info()
  end
end
