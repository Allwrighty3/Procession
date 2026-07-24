defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the primitive-body sibling developmental diagnostic"

  @impl true
  def run(_args) do
    Procession.Simulation.PrimitiveDevelopmentExperiment.run(
      population: 2,
      baby_ticks: 100,
      participation_ticks: 100,
      withdrawal_ticks: 200
    )
    |> Procession.Simulation.PrimitiveDevelopmentExperiment.report()
    |> Mix.shell().info()
  end
end
