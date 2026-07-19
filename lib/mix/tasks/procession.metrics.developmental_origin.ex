defmodule Mix.Tasks.Procession.Metrics.DevelopmentalOrigin do
  use Mix.Task

  @shortdoc "Compares developmental structure across history and rule variants"

  alias Procession.Simulation.DevelopmentalOriginExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        strict: [ticks: :integer, seed: :integer, output: :string],
        aliases: [t: :ticks, s: :seed, o: :output]
      )

    result =
      DevelopmentalOriginExperiment.run(
        ticks: Keyword.get(opts, :ticks, 720),
        seed: Keyword.get(opts, :seed, 1)
      )

    report = DevelopmentalOriginExperiment.report(result)
    Mix.shell().info(report)

    if output = opts[:output], do: File.write!(output, report <> "\n")
  end
end
