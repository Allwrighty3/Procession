defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the closed-loop mental-plane sibling diagnostic"

  @impl true
  def run(_args) do
    Procession.Simulation.ClosedLoopPrimitiveExperiment.run(
      population: 2,
      baby_ticks: 100,
      participation_ticks: 100,
      withdrawal_ticks: 200
    )
    |> Procession.Simulation.ClosedLoopPrimitiveExperiment.report()
    |> Mix.shell().info()
  end
end
