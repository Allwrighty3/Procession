defmodule Mix.Tasks.Procession.Metrics.UntaughtGridLearning do
  use Mix.Task

  alias Procession.Simulation.UntaughtGridLearningExperiment

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          population: :integer,
          ticks: :integer,
          training_ticks: :integer,
          seed: :integer,
          output: :string
        ]
      )

    report =
      opts
      |> UntaughtGridLearningExperiment.run()
      |> UntaughtGridLearningExperiment.report()

    case Keyword.get(opts, :output) do
      nil -> Mix.shell().info(report)
      path -> File.write!(path, report <> "\n")
    end
  end
end
