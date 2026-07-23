defmodule Mix.Tasks.Procession.Metrics.HomeForagingDriveGating do
  use Mix.Task

  @shortdoc "Runs the continuous drive-gating comparison"

  @impl true
  def run(_args) do
    Procession.Simulation.HomeForagingDriveGatingExperiment.run()
    |> Procession.Simulation.HomeForagingDriveGatingExperiment.report()
    |> Mix.shell().info()
  end
end