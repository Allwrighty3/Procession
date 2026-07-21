defmodule Mix.Tasks.Procession.Metrics.HomeForagingContingency do
  use Mix.Task

  @shortdoc "Runs transition-sensitive and slow-lived home-foraging learners"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args,
      strict: [population: :integer, seed: :integer, output: :string])

    result = Procession.Simulation.HomeForagingContingencyExperiment.run(
      population: Keyword.get(opts, :population, 24),
      seed: Keyword.get(opts, :seed, 1)
    )

    report = Procession.Simulation.HomeForagingContingencyExperiment.report(result)
    Mix.shell().info(report)

    if path = opts[:output], do: File.write!(path, report <> "\n")
  end
end
