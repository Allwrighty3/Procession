defmodule Mix.Tasks.Procession.Metrics.CompressionCost do
  use Mix.Task

  @shortdoc "Measures whether developmental compression pays for its runtime cost"

  alias Procession.Simulation.CompressionCostExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [ticks: :integer, seed: :integer, samples: :integer, output: :string]
      )

    result = CompressionCostExperiment.run(opts)
    report = CompressionCostExperiment.report(result)

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path ->
        File.write!(path, report <> "\n")
        Mix.shell().info("wrote #{path}")
    end
  end
end