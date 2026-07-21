defmodule Mix.Tasks.Procession.Metrics.HomeForagingEmergentMotorTimescaleMatrix do
  use Mix.Task

  @shortdoc "Runs the emergent-motor timescale matrix"

  alias Procession.Simulation.HomeForagingEmergentMotorTimescaleMatrix, as: Matrix

  @impl Mix.Task
  def run(_args) do
    Matrix.run()
    |> Matrix.report()
    |> Mix.shell().info()
  end
end
