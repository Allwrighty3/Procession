defmodule Mix.Tasks.Procession.Metrics.DependentSurvivorAnalysis do
  use Mix.Task

  alias Procession.Simulation.DependentSurvivorAnalysisExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          population: :integer,
          baby_ticks: :integer,
          participation_ticks: :integer,
          withdrawal_ticks: :integer,
          seed: :integer,
          output: :string
        ]
      )

    report =
      opts
      |> DependentSurvivorAnalysisExperiment.run()
      |> DependentSurvivorAnalysisExperiment.report()

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path -> File.write!(path, report <> "\n")
    end
  end
end
