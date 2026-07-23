defmodule Mix.Tasks.Procession.Metrics.HomeForagingUngroundedControl do
  use Mix.Task

  alias Procession.Simulation.HomeForagingUngroundedControlExperiment

  @shortdoc "Runs the ungrounded no-teacher home-foraging control"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} = OptionParser.parse(args,
      strict: [population: :integer, seed: :integer, ticks: :integer, output: :string]
    )

    result = HomeForagingUngroundedControlExperiment.run(opts)
    report = HomeForagingUngroundedControlExperiment.report(result)

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path -> File.write!(path, report <> "\n")
    end
  end
end
