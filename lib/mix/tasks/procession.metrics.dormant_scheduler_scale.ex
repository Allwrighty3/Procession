defmodule Mix.Tasks.Procession.Metrics.DormantSchedulerScale do
  use Mix.Task

  @shortdoc "Runs the dormant scheduler scale and fairness experiment"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        strict: [ticks: :integer, populations: :string, budgets: :string, cadences: :string]
      )

    experiment_opts =
      []
      |> maybe_put(:ticks, Keyword.get(opts, :ticks))
      |> maybe_put(:populations, parse_integer_list(Keyword.get(opts, :populations)))
      |> maybe_put(:budgets, parse_integer_list(Keyword.get(opts, :budgets)))
      |> maybe_put(:cadences, parse_integer_list(Keyword.get(opts, :cadences)))

    result = Procession.Simulation.DormantSchedulerScaleExperiment.run(experiment_opts)
    Mix.shell().info(inspect(result, pretty: true, limit: :infinity))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_integer_list(nil), do: nil

  defp parse_integer_list(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
  end
end
