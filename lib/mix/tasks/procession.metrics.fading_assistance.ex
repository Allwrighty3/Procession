defmodule Mix.Tasks.Procession.Metrics.FadingAssistance do
  use Mix.Task

  @shortdoc "Runs staged caregiver assistance fading metrics"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [population: :integer, stage_ticks: :integer, withdrawal_ticks: :integer,
        seed: :integer, output: :string])

    result = Procession.Simulation.FadingAssistanceExperiment.run(opts)
    report = Procession.Simulation.FadingAssistanceExperiment.report(result)
    Mix.shell().info(report)

    if path = opts[:output], do: File.write!(path, report <> "\n")
  end
end
