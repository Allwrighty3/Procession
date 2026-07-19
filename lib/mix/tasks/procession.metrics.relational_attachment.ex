defmodule Mix.Tasks.Procession.Metrics.RelationalAttachment do
  use Mix.Task

  @shortdoc "Compares relational-field caregiver development controls"

  alias Procession.Simulation.RelationalAttachmentExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, output: :string]
      )

    samples = Keyword.get(opts, :samples, 20)
    ticks = Keyword.get(opts, :ticks, 1_800)
    seeds = Enum.to_list(1..samples)

    conditions = [
      responsive_regulated: [parent_mode: :responsive, regulated: true],
      passive_regulated: [parent_mode: :passive, regulated: true],
      responsive_unregulated: [parent_mode: :responsive, regulated: false],
      no_parent: [parent_mode: :none, regulated: false]
    ]

    report =
      ["Relational field attachment metrics", "samples=#{samples} ticks=#{ticks}"] ++
        Enum.map(conditions, fn {name, condition_opts} ->
          summary = Experiment.compare(condition_opts ++ [seeds: seeds, ticks: ticks])
          "#{name}: #{Experiment.report(summary)}"
        end)
      |> Enum.join("\n")

    output = Keyword.get(opts, :output, "relational-attachment-metrics.txt")
    File.write!(output, report <> "\n")
    Mix.shell().info(report)
  end
end
