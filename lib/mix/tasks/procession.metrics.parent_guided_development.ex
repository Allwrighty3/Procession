defmodule Mix.Tasks.Procession.Metrics.ParentGuidedDevelopment do
  use Mix.Task

  @shortdoc "Compares parent-guided and no-parent developmental worlds"

  alias Procession.Simulation.ParentGuidedDevelopmentExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, first_seed: :integer, output: :string],
        aliases: [n: :samples, t: :ticks, o: :output]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    samples = positive!(Keyword.get(opts, :samples, 20), "samples")
    ticks = positive!(Keyword.get(opts, :ticks, 1_500), "ticks")
    first_seed = Keyword.get(opts, :first_seed, 1)
    seeds = Enum.to_list(first_seed..(first_seed + samples - 1))
    common = [ticks: ticks, seeds: seeds, resource_regen: 0.002]

    guided = Experiment.compare(common)

    no_parent =
      Experiment.compare(
        Keyword.merge(common,
          parent_departure: 0,
          carry_until: 0
        )
      )

    report =
      [
        "Parent-guided developmental control metrics",
        "samples=#{samples} ticks=#{ticks} seeds=#{first_seed}..#{first_seed + samples - 1}",
        "",
        "parent_guided: #{Experiment.report(guided)}",
        "no_parent: #{Experiment.report(no_parent)}"
      ]
      |> Enum.join("\n")
      |> Kernel.<>("\n")

    IO.write(report)

    case Keyword.get(opts, :output) do
      nil -> :ok
      path -> File.write!(path, report)
    end
  end

  defp positive!(value, _name) when is_integer(value) and value > 0, do: value
  defp positive!(_value, name), do: Mix.raise("#{name} must be a positive integer")
end
