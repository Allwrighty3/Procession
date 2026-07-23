defmodule Mix.Tasks.Procession.Metrics.ObsoletePathBalance do
  use Mix.Task

  @shortdoc "Measures obsolete-path reinforcement versus contradiction"

  alias Procession.Simulation.ObsoletePathBalanceExperiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [output: :string, summary_output: :string, seeds: :integer]
      )

    seed_count = Keyword.get(opts, :seeds, 100)
    rows = ObsoletePathBalanceExperiment.run_many(seeds: Enum.to_list(1..seed_count))
    summary = ObsoletePathBalanceExperiment.summarize(rows)
    report = ObsoletePathBalanceExperiment.report(summary)

    case Keyword.get(opts, :output) do
      nil -> :ok
      path ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, Enum.map_join(rows, "\n", &(Jason.encode!(&1))) <> "\n")
    end

    case Keyword.get(opts, :summary_output) do
      nil -> :ok
      path ->
        File.mkdir_p!(Path.dirname(path))
        File.write!(path, report <> "\n")
    end

    Mix.shell().info(report)
  end
end
