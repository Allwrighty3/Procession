defmodule Mix.Tasks.Procession.Metrics.DevelopmentalPopulation do
  use Mix.Task

  @shortdoc "Measures developmental divergence and consolidation coverage"

  alias Procession.Simulation.DevelopmentalPopulationExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [population: :integer, ticks: :integer, seed: :integer, output: :string]
      )

    result = DevelopmentalPopulationExperiment.run(opts)
    report = DevelopmentalPopulationExperiment.report(result)

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path ->
        File.write!(path, report <> "\n")
        Mix.shell().info("wrote #{path}")
    end
  end
end