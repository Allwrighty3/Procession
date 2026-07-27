defmodule Mix.Tasks.Procession.Metrics.ThreeRegionMigration do
  use Mix.Task

  @shortdoc "Runs the three-region dormant migration vertical slice"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [ticks: :integer, budget: :integer, cadence: :integer, seed: :integer]
      )

    result = Procession.Simulation.ThreeRegionMigrationExperiment.run(opts)
    Mix.shell().info(inspect(result, pretty: true, limit: :infinity))
  end
end
