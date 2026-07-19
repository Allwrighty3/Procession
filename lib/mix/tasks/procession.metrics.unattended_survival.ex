defmodule Mix.Tasks.Procession.Metrics.UnattendedSurvival do
  use Mix.Task

  alias Procession.Simulation.UnattendedSurvivalExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [population: :integer, ticks: :integer, seed: :integer, output: :string]
      )

    report =
      opts
      |> UnattendedSurvivalExperiment.run()
      |> UnattendedSurvivalExperiment.report()

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path -> File.write!(path, report <> "\n")
    end
  end
end
