defmodule Mix.Tasks.Procession.Metrics.ParentGuidedDevelopment do
  use Mix.Task

  @shortdoc "Runs parent-guided developmental world metrics"

  alias Procession.Simulation.ParentGuidedDevelopmentExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, first_seed: :integer],
        aliases: [n: :samples, t: :ticks]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    samples = positive!(Keyword.get(opts, :samples, 20), "samples")
    ticks = positive!(Keyword.get(opts, :ticks, 1_500), "ticks")
    first_seed = Keyword.get(opts, :first_seed, 1)
    seeds = Enum.to_list(first_seed..(first_seed + samples - 1))

    summary = Experiment.compare(ticks: ticks, seeds: seeds, resource_regen: 0.002)

    IO.puts("Parent-guided developmental world metrics")
    IO.puts("samples=#{samples} ticks=#{ticks} seeds=#{first_seed}..#{first_seed + samples - 1}\n")
    IO.puts(Experiment.report(summary))
  end

  defp positive!(value, _name) when is_integer(value) and value > 0, do: value
  defp positive!(_value, name), do: Mix.raise("#{name} must be a positive integer")
end
