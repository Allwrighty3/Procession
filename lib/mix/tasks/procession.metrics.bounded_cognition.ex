defmodule Mix.Tasks.Procession.Metrics.BoundedCognition do
  use Mix.Task

  @shortdoc "Runs the bounded cognition prospective-action probe"

  @impl true
  def run(_args) do
    Procession.Simulation.BoundedCognitionExperiment.run()
    |> Procession.Simulation.BoundedCognitionExperiment.report()
    |> Mix.shell().info()
  end
end
