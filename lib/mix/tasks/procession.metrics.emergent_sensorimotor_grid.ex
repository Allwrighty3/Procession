defmodule Mix.Tasks.Procession.Metrics.EmergentSensorimotorGrid do
  use Mix.Task

  alias Procession.Simulation.EmergentSensorimotorGridExperiment, as: Experiment

  @shortdoc "Reports emergent multisensory behavior and compression in the hidden 4x4 world"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Enum.each([160, 320, 640, 1_280], fn ticks ->
      state = Experiment.run(ticks: ticks)
      metrics = Experiment.instrumentation(state)

      IO.puts(
        "ticks=#{ticks} alive=#{metrics.alive} energy=#{fmt(metrics.energy)} " <>
          "intake=#{fmt(metrics.intake)} appetitive_feedback=#{fmt(metrics.appetitive_feedback)} " <>
          "mouth_watering=#{fmt(metrics.mouth_watering)}"
      )

      IO.puts(
        "hidden_cells_visited=#{metrics.hidden_cells_visited} visual_channels=#{metrics.visual_channels} " <>
          "learned_sensorimotor_links=#{metrics.learned_sensorimotor_links} " <>
          "output_usage=#{inspect(metrics.output_usage)}"
      )

      IO.puts(
        "world_effects=#{inspect(metrics.world_effects)} " <>
          "boundary_impacts=#{inspect(metrics.boundary_impacts)}"
      )

      IO.puts(
        "assemblies=#{metrics.assembly_count} largest=#{metrics.maximum_assembly_size} " <>
          "tracked=#{metrics.tracked_motifs}"
      )

      IO.puts(
        "transitions=#{metrics.detailed_transitions}->#{metrics.effective_transitions} " <>
          "saved=#{metrics.transitions_saved} ratio=#{fmt(metrics.compression_ratio)}"
      )

      Experiment.assemblies(state)
      |> Enum.take(8)
      |> Enum.each(fn assembly ->
        IO.puts(
          "assembly size=#{assembly.size} occurrences=#{fmt(assembly.occurrences)} " <>
            "confidence=#{fmt(assembly.confidence)} members=#{inspect(assembly.members)}"
        )
      end)

      IO.puts("")
    end)
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 4)
end
