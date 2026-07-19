defmodule Mix.Tasks.Procession.Metrics.DevelopmentalTendencies do
  use Mix.Task

  alias Procession.Simulation.IndependenceDevelopmentExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [population: :integer, phase_ticks: :integer, seed: :integer, output: :string])

    report = opts |> IndependenceDevelopmentExperiment.run() |> IndependenceDevelopmentExperiment.report()

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path -> File.write!(path, report <> "\n")
    end
  end
end
