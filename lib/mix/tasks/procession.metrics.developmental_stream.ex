defmodule Mix.Tasks.Procession.Metrics.DevelopmentalStream do
  use Mix.Task

  @shortdoc "Observes unlabeled structure formed from a developmental body stream"

  alias Procession.Simulation.DevelopmentalStreamExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        strict: [ticks: :integer, seed: :integer, output: :string],
        aliases: [t: :ticks, s: :seed, o: :output]
      )

    result =
      DevelopmentalStreamExperiment.run(
        ticks: Keyword.get(opts, :ticks, 720),
        seed: Keyword.get(opts, :seed, 1)
      )

    report = DevelopmentalStreamExperiment.report(result)
    Mix.shell().info(report)

    if output = opts[:output] do
      File.write!(output, report <> "\n")
    end
  end
end