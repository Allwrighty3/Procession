defmodule Mix.Tasks.Procession.Metrics.ParentGuidedDevelopment do
  use Mix.Task

  @shortdoc "Compares parent-guided and no-parent developmental worlds"

  alias Procession.Simulation.ParentGuidedDevelopmentExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, first_seed: :integer, output: :string],
        aliases: [n: :samples, t: :ticks, o: :output]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    output = Keyword.get(opts, :output, "parent-guided-development-metrics.txt")

    report =
      try do
        build_report(opts)
      rescue
        error ->
          "Parent-guided developmental control metrics FAILED\n" <>
            Exception.format(:error, error, __STACKTRACE__)
      end

    File.write!(output, report)
    IO.write(report)
  end

  defp build_report(opts) do
    samples = positive!(Keyword.get(opts, :samples, 20), "samples")
    ticks = positive!(Keyword.get(opts, :ticks, 1_500), "ticks")
    first_seed = Keyword.get(opts, :first_seed, 1)
    seeds = Enum.to_list(first_seed..(first_seed + samples - 1))
    common = [ticks: ticks, seeds: seeds, resource_regen: 0.002]

    guided = Experiment.compare(common)
    no_parent = Experiment.compare(Keyword.merge(common, parent_departure: 0, carry_until: 0))

    "Parent-guided developmental control metrics\n" <>
      "samples=#{samples} ticks=#{ticks} seeds=#{first_seed}..#{first_seed + samples - 1}\n\n" <>
      "parent_guided: #{Experiment.report(guided)}\n" <>
      "no_parent: #{Experiment.report(no_parent)}\n"
  end

  defp positive!(value, _name) when is_integer(value) and value > 0, do: value
  defp positive!(_value, name), do: Mix.raise("#{name} must be a positive integer")
end
