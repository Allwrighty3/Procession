defmodule Mix.Tasks.Procession.Metrics.HomeForagingSeedReplication do
  use Mix.Task

  @shortdoc "Replicates slow long-lived home-foraging across disjoint seeds"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [population: :integer, seeds: :string, output: :string]
      )

    seeds =
      opts
      |> Keyword.get(:seeds, "101,211,307,401,503")
      |> String.split(",", trim: true)
      |> Enum.map(&String.to_integer/1)

    result =
      Procession.Simulation.HomeForagingSeedReplication.run(
        population: Keyword.get(opts, :population, 24),
        seeds: seeds
      )

    report = Procession.Simulation.HomeForagingSeedReplication.report(result)
    Mix.shell().info(report)

    if path = opts[:output], do: File.write!(path, report <> "\n")
  end
end
