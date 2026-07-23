defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the simultaneous sibling-only developmental diagnostic"

  @impl true
  def run(_args) do
    Procession.Simulation.SiblingPairSurvivalExperiment.run()
    |> Procession.Simulation.SiblingPairSurvivalExperiment.report()
    |> Mix.shell().info()
  end
end
