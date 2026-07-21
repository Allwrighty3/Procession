defmodule Mix.Tasks.Procession.Metrics.LearnerOwnedAssistance do
  use Mix.Task

  @shortdoc "Runs learner-owned caregiver assistance metrics"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args,
      strict: [population: :integer, stage_ticks: :integer,
        withdrawal_ticks: :integer, seed: :integer, output: :string])

    report = opts
      |> Keyword.delete(:output)
      |> Procession.Simulation.LearnerOwnedAssistanceExperiment.run()
      |> Procession.Simulation.LearnerOwnedAssistanceExperiment.report()

    Mix.shell().info(report)
    if path = opts[:output], do: File.write!(path, report <> "\n")
  end
end
