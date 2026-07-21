defmodule Mix.Tasks.Procession.Metrics.RecursiveMemoryQuality do
  use Mix.Task

  @shortdoc "Runs recursive memory retrieval and hierarchy-quality audits"

  @impl true
  def run(_args) do
    retrieval =
      Procession.Simulation.RecursiveMemoryQualityExperiment.run()
      |> Procession.Simulation.RecursiveMemoryQualityExperiment.report()

    hierarchy =
      Procession.Simulation.RecursiveMemoryHierarchyExperiment.run()
      |> Procession.Simulation.RecursiveMemoryHierarchyExperiment.report()

    Mix.shell().info(retrieval <> "\n\n" <> hierarchy)
  end
end
