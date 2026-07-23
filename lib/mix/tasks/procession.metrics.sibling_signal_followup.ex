defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the blinded sibling and arbitrary-signal follow-up"

  @impl true
  def run(_args) do
    Procession.Simulation.SiblingSignalFollowupExperiment.run(
      population: 12,
      teaching_ticks: 120,
      transfer_ticks: 320,
      seed: 73
    )
    |> Procession.Simulation.SiblingSignalFollowupExperiment.report()
    |> Mix.shell().info()
  end
end
