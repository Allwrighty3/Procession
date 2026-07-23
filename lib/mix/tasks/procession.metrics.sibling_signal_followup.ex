defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the ultra-slow equal-blind OTP sibling diagnostic"

  @impl true
  def run(_args) do
    Procession.Simulation.SiblingSignalFollowupExperiment.run()
    |> Procession.Simulation.SiblingSignalFollowupExperiment.report()
    |> Mix.shell().info()
  end
end
