defmodule Mix.Tasks.Procession.Metrics.FadingAssistance do
  use Mix.Task

  @shortdoc "Runs staged caregiver assistance fading metrics"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          population: :integer,
          stage_ticks: :integer,
          withdrawal_ticks: :integer,
          seed: :integer,
          output: :string,
          compare_action_costs: :boolean
        ]
      )

    report =
      if Keyword.get(opts, :compare_action_costs, false) do
        opts
        |> Keyword.delete(:compare_action_costs)
        |> Keyword.delete(:output)
        |> Procession.Simulation.FadingAssistanceExperiment.compare_action_costs()
        |> Procession.Simulation.FadingAssistanceExperiment.comparison_report()
      else
        opts
        |> Procession.Simulation.FadingAssistanceExperiment.run()
        |> Procession.Simulation.FadingAssistanceExperiment.report()
      end

    Mix.shell().info(report)

    if path = opts[:output], do: File.write!(path, report <> "\n")
  end
end