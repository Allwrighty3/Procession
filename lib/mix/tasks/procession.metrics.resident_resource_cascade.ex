defmodule Mix.Tasks.Procession.Metrics.ResidentResourceCascade do
  use Mix.Task

  @moduledoc "Runs the resident-driven regional material cascade experiment."
  @shortdoc "Reports resident material cascade metrics"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [ticks: :integer, budget: :integer, cadence: :integer, seed: :integer]
      )

    result = Procession.Simulation.ResidentResourceCascadeExperiment.run(opts)
    Mix.shell().info(inspect(result, pretty: true, limit: :infinity))
  end
end
