defmodule Mix.Tasks.Procession.Metrics.DependentDevelopment do
  use Mix.Task

  alias Procession.Simulation.DependentDevelopmentExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [population: :integer, baby_ticks: :integer, participation_ticks: :integer,
        withdrawal_ticks: :integer, seed: :integer, output: :string])

    report = opts |> DependentDevelopmentExperiment.run() |> DependentDevelopmentExperiment.report()

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path -> File.write!(path, report <> "\n")
    end
  end
end
