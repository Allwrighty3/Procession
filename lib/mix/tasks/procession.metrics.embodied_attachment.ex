defmodule Mix.Tasks.Procession.Metrics.EmbodiedAttachment do
  use Mix.Task

  @shortdoc "Runs embodied caregiver regulation metrics"

  alias Procession.Simulation.EmbodiedAttachmentExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, first_seed: :integer],
        aliases: [n: :samples, t: :ticks]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    samples = Keyword.get(opts, :samples, 20)
    ticks = Keyword.get(opts, :ticks, 1_800)
    first_seed = Keyword.get(opts, :first_seed, 1)
    seeds = Enum.to_list(first_seed..(first_seed + samples - 1))

    regulated = Experiment.compare(ticks: ticks, seeds: seeds)

    unregulated =
      Experiment.compare(
        ticks: ticks,
        seeds: seeds,
        caregiver_warmth: 0.0,
        caregiver_provision: 0.0,
        caregiver_recovery: 0.0
      )

    no_parent =
      Experiment.compare(
        ticks: ticks,
        seeds: seeds,
        parent_departure: 0,
        caregiver_warmth: 0.0,
        caregiver_provision: 0.0,
        caregiver_recovery: 0.0
      )

    report = [
      "Embodied caregiver regulation metrics",
      "samples=#{samples} ticks=#{ticks} seeds=#{first_seed}..#{first_seed + samples - 1}",
      "",
      "regulated:   #{Experiment.report(regulated)}",
      "unregulated: #{Experiment.report(unregulated)}",
      "no_parent:   #{Experiment.report(no_parent)}"
    ] |> Enum.join("\n")

    File.write!("embodied-attachment-metrics.txt", report <> "\n")
    IO.puts(report)
  end
end
