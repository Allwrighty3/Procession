defmodule Mix.Tasks.Procession.Metrics.HomeForagingPressureControl do
  use Mix.Task

  @shortdoc "Runs the home-foraging pressure and teacher-control experiment"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _, _} = OptionParser.parse(args,
      strict: [population: :integer, seed: :integer, output: :string]
    )

    result = Procession.Simulation.HomeForagingPressureControlExperiment.run(
      population: Keyword.get(parsed, :population, 24),
      seed: Keyword.get(parsed, :seed, 1)
    )

    report = Procession.Simulation.HomeForagingPressureControlExperiment.report(result)
    Mix.shell().info(report)

    case parsed[:output] do
      nil -> :ok
      path -> File.write!(path, report <> "\n")
    end
  end
end
