defmodule Mix.Tasks.Procession.Metrics.TrajectoryLandscape do
  use Mix.Task

  @shortdoc "Measures trajectory carving and cue-driven replay in the developmental field"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [repetitions: :integer, idle_ticks: :integer, output: :string]
      )

    result = Procession.Simulation.TrajectoryLandscapeProbe.run(opts)
    report = Procession.Simulation.TrajectoryLandscapeProbe.report(result)
    Mix.shell().info(report)

    if path = opts[:output], do: File.write!(path, report <> "\n")
  end
end
