defmodule Mix.Tasks.Procession.Metrics.ClosedGridWorld do
  use Mix.Task

  @shortdoc "Runs closed 4x4 embodied world metrics"

  alias Procession.Simulation.ClosedGridWorldExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, first_seed: :integer],
        aliases: [n: :samples, t: :ticks]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    samples = positive!(Keyword.get(opts, :samples, 100), "samples")
    ticks = positive!(Keyword.get(opts, :ticks, 320), "ticks")
    first_seed = Keyword.get(opts, :first_seed, 1)
    seeds = Enum.to_list(first_seed..(first_seed + samples - 1))

    results = Experiment.compare(ticks: ticks, seeds: seeds)

    Mix.shell().info("Closed 4x4 embodied world metrics")
    Mix.shell().info("samples=#{samples} ticks=#{ticks} seeds=#{first_seed}..#{first_seed + samples - 1}\n")
    Mix.shell().info(Experiment.report(results))
  end

  defp positive!(value, _name) when is_integer(value) and value > 0, do: value
  defp positive!(_value, name), do: Mix.raise("#{name} must be a positive integer")
end
