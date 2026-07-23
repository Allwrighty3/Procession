defmodule Mix.Tasks.Procession.Metrics.HomeForagingChildScale do
  use Mix.Task

  alias Procession.Simulation.HomeForagingChildScaleExperiment, as: Experiment

  @shortdoc "Runs the child-scale emergent-motor taught comparison"

  @impl Mix.Task
  def run(_args) do
    Experiment.run()
    |> Experiment.report()
    |> Mix.shell().info()
  end
end
