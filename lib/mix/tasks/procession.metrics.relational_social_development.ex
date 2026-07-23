defmodule Mix.Tasks.Procession.Metrics.RelationalSocialDevelopment do
  use Mix.Task

  @shortdoc "Runs relational transfer, sibling, and signal diagnostics"

  @impl true
  def run(_args) do
    Procession.Simulation.RelationalSocialDevelopmentExperiment.run(
      population: 24,
      teaching_ticks: 320,
      transfer_ticks: 480,
      seed: 41
    )
    |> Procession.Simulation.RelationalSocialDevelopmentExperiment.report()
    |> Mix.shell().info()
  end
end
