defmodule Mix.Tasks.Procession.Metrics.HomeForagingEnergy do
  use Mix.Task

  alias Procession.Simulation.HomeForagingEnergyExperiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [population: :integer, stage_ticks: :integer, withdrawal_ticks: :integer,
          seed: :integer, output: :string]
      )

    output = Keyword.get(opts, :output, "home-foraging-energy.txt")
    result = HomeForagingEnergyExperiment.run(opts)
    report = HomeForagingEnergyExperiment.report(result)
    File.write!(output, report <> "\n")
    Mix.shell().info(report)
  end
end
