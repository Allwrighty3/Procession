defmodule Mix.Tasks.Procession.Metrics.HomeForagingRecursiveMemory do
  use Mix.Task

  @shortdoc "Runs the recursive memory-plane motor integration audit"

  alias Procession.Simulation.HomeForagingRecursiveMemoryIntegration, as: Experiment

  @impl Mix.Task
  def run(_args) do
    Experiment.run()
    |> Experiment.report()
    |> Mix.shell().info()
  end
end
