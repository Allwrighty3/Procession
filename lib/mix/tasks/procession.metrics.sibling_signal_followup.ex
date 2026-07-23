defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the blinded sibling and arbitrary-signal follow-up"

  @impl true
  def run(_args) do
    # The standard developmental simulation uses the same ultra-slow regime as
    # the established home-foraging pressure experiments: 8,000 total ticks
    # and 0.01x output learning. Recompile this isolated diagnostic module with
    # that learning scale so production learner modules remain untouched.
    module = Procession.Simulation.SiblingSignalFollowupExperiment
    path = "lib/procession/simulation/sibling_signal_followup_experiment.ex"

    source =
      path
      |> File.read!()
      |> String.replace("output_learning_scale: 0.20", "output_learning_scale: 0.01")

    :code.purge(module)
    :code.delete(module)
    Code.compile_string(source, path)

    module.run(
      population: 12,
      teaching_ticks: 5_000,
      transfer_ticks: 3_000,
      seed: 73
    )
    |> module.report()
    |> Mix.shell().info()
  end
end
