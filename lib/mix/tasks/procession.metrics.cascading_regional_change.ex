defmodule Mix.Tasks.Procession.Metrics.CascadingRegionalChange do
  use Mix.Task

  @moduledoc "Runs the cascading three-region dormant migration and regional feedback experiment."
  @shortdoc "Runs cascading regional change metrics"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [ticks: :integer, budget: :integer, cadence: :integer, seed: :integer]
      )

    result = Procession.Simulation.CascadingRegionalChangeExperiment.run(opts)
    Mix.shell().info(inspect(result, pretty: true, limit: :infinity))
  end
end
