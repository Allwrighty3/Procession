defmodule Mix.Tasks.Procession.Metrics.HomeForagingEmergentMotorControl do
  use Mix.Task

  @shortdoc "Runs the emergent-movement no-teacher developmental control"

  alias Procession.Simulation.HomeForagingEmergentMotorControlExperiment, as: Experiment

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    result = Experiment.run()
    Mix.shell().info(Experiment.report(result))
  end
end
