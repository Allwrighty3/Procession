defmodule Mix.Tasks.Procession.Metrics.ActionCostReversal do
  use Mix.Task

  alias Procession.Simulation.ActionCostReversalExperiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [output: :string, summary_output: :string, seeds: :integer]
      )

    seed_count = Keyword.get(opts, :seeds, 100)
    rows = ActionCostReversalExperiment.run_many(Enum.to_list(1..seed_count))
    summary = ActionCostReversalExperiment.summarize(rows)
    report = ActionCostReversalExperiment.report(summary)

    if path = Keyword.get(opts, :output) do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, Enum.map_join(rows, "\n", &Jason.encode!/1) <> "\n")
    end

    if path = Keyword.get(opts, :summary_output) do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, report <> "\n")
    end

    Mix.shell().info(report)
  end
end
