defmodule Mix.Tasks.Procession.Metrics.ClosedGridActionCompression do
  use Mix.Task

  alias Procession.Simulation.ClosedGridActionCompressionExperiment, as: Experiment

  @shortdoc "Measures natural compression in the robust 4x4 action world"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    for ticks <- [160, 320, 640] do
      state = Experiment.run(ticks: ticks, initial_energy: 0.35)
      metrics = Experiment.instrumentation(state)

      IO.puts(Enum.join([
        "ticks=#{ticks}",
        "survived=#{state.alive}",
        "energy=#{fmt(state.energy)}",
        "intake=#{fmt(state.intake)}",
        "events=#{metrics.event_count}",
        "assemblies=#{metrics.assembly_count}",
        "largest=#{metrics.maximum_assembly_size}",
        "tracked_motifs=#{metrics.tracked_motifs}",
        "saved=#{metrics.transitions_saved}",
        "compression_ratio=#{fmt(metrics.compression_ratio)}",
        "actions=#{inspect(metrics.action_counts)}"
      ], " "))

      Experiment.assemblies(state)
      |> Enum.take(12)
      |> Enum.each(fn assembly ->
        IO.puts("assembly size=#{assembly.size} occurrences=#{fmt(assembly.occurrences)} " <>
          "confidence=#{fmt(assembly.confidence)} members=#{inspect(assembly.members)}")
      end)
    end
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end
