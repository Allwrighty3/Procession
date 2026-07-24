defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the primitive-body sibling developmental diagnostic"

  @impl true
  def run(_args) do
    Procession.Simulation.PrimitiveDevelopmentExperiment.run(
      population: 4,
      baby_ticks: 500,
      participation_ticks: 500,
      withdrawal_ticks: 1_000
    )
    |> Procession.Simulation.PrimitiveDevelopmentExperiment.report()
    |> Mix.shell().info()
  end
end
