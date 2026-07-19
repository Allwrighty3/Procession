defmodule Mix.Tasks.Procession.Metrics.PhysicalGuidance do
  use Mix.Task

  alias Procession.Simulation.PhysicalGuidanceExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [population: :integer, assisted_ticks: :integer,
        withdrawal_ticks: :integer, seed: :integer, output: :string])

    report = opts |> PhysicalGuidanceExperiment.run() |> PhysicalGuidanceExperiment.report()

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path -> File.write!(path, report <> "\n")
    end
  end
end
