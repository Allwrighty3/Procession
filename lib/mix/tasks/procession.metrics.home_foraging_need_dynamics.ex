defmodule Mix.Tasks.Procession.Metrics.HomeForagingNeedDynamics do
  use Mix.Task

  @shortdoc "Runs the continuous need-dynamics learner comparison"

  @impl true
  def run(_args) do
    Procession.Simulation.HomeForagingNeedDynamicsExperiment.run()
    |> Procession.Simulation.HomeForagingNeedDynamicsExperiment.report()
    |> Mix.shell().info()
  end
end
