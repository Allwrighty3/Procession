defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the primitive-body sibling developmental diagnostic"

  @impl true
  def run(_args) do
    Procession.Simulation.PrimitiveDevelopmentExperiment.run(population: 4)
    |> Procession.Simulation.PrimitiveDevelopmentExperiment.report()
    |> Mix.shell().info()
  end
end
