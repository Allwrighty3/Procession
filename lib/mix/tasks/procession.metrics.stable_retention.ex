defmodule Mix.Tasks.Procession.Metrics.StableRetention do
  use Mix.Task

  @shortdoc "Runs stable-environment retention metrics"

  alias Procession.Simulation.StableRetentionFactorialExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, acquisition_window: :integer],
        aliases: [n: :samples, t: :ticks]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    samples = positive!(Keyword.get(opts, :samples, 100), "samples")
    ticks = positive!(Keyword.get(opts, :ticks, 220), "ticks")
    acquisition_window =
      positive!(Keyword.get(opts, :acquisition_window, div(ticks, 2)), "acquisition_window")

    results =
      Experiment.compare(
        ticks: ticks,
        acquisition_window: acquisition_window,
        seeds: Enum.to_list(1..samples)
      )

    Mix.shell().info("Stable retention factorial metrics")
    Mix.shell().info(
      "samples=#{samples} ticks=#{ticks} acquisition_window=#{acquisition_window}\n"
    )
    Mix.shell().info(Experiment.report(results))
  end

  defp positive!(value, _name) when is_integer(value) and value > 0, do: value
  defp positive!(_value, name), do: Mix.raise("#{name} must be a positive integer")
end
