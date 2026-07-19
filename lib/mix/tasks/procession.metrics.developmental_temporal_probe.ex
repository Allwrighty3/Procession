defmodule Mix.Tasks.Procession.Metrics.DevelopmentalTemporalProbe do
  use Mix.Task

  @shortdoc "Runs extended probes for temporal emergence without adding temporal machinery"

  alias Procession.Simulation.DevelopmentalTemporalProbe

  @impl Mix.Task
  def run(args) do
    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        strict: [seed: :integer, output: :string],
        aliases: [s: :seed, o: :output]
      )

    result = DevelopmentalTemporalProbe.run(seed: Keyword.get(opts, :seed, 1))
    report = DevelopmentalTemporalProbe.report(result)
    Mix.shell().info(report)

    if output = opts[:output] do
      File.write!(output, report <> "\n")
    end
  end
end
