defmodule Mix.Tasks.Procession.Metrics.ResponsiveParent do
  use Mix.Task

  @shortdoc "Compare responsive raising with caregiver controls"

  alias Procession.Simulation.EmbodiedAttachmentExperiment, as: Passive
  alias Procession.Simulation.ResponsiveParentExperiment, as: Responsive

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [samples: :integer, ticks: :integer, output: :string])
    samples = opts[:samples] || 20
    ticks = opts[:ticks] || 1_800
    seeds = Enum.to_list(1..samples)

    responsive = Responsive.compare(seeds: seeds, ticks: ticks)
    responsive_unregulated = Responsive.compare(seeds: seeds, ticks: ticks,
      caregiver_warmth: 0.0, caregiver_provision: 0.0, caregiver_recovery: 0.0)
    passive = Passive.compare(seeds: seeds, ticks: ticks)
    no_parent = Passive.compare(seeds: seeds, ticks: ticks, parent_departure: 0,
      caregiver_warmth: 0.0, caregiver_provision: 0.0, caregiver_recovery: 0.0)

    report = [
      "Responsive parent developmental metrics",
      "samples=#{samples} ticks=#{ticks} seeds=1..#{samples}",
      "",
      "responsive_regulated: #{Responsive.report(responsive)}",
      "responsive_unregulated: #{Responsive.report(responsive_unregulated)}",
      "passive_regulated: #{Passive.report(passive)}",
      "no_parent: #{Passive.report(no_parent)}"
    ] |> Enum.join("\n")

    IO.puts(report)
    if opts[:output], do: File.write!(opts[:output], report <> "\n")
  end
end
