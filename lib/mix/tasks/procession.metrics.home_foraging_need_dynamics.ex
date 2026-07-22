defmodule Mix.Tasks.Procession.Metrics.HomeForagingNeedDynamics do
  use Mix.Task

  @shortdoc "Runs the continuous need-dynamics learner comparison"

  @impl true
  def run(_args) do
    Procession.Simulation.HomeForagingNeedDynamicsExperiment.run(
      population: 12,
      teaching_ticks: 2_400,
      withdrawal_ticks: 2_400
    )
    |> Procession.Simulation.HomeForagingNeedDynamicsExperiment.report()
    |> Mix.shell().info()
  end
end
