defmodule Mix.Tasks.Procession.Metrics.LocalInterpersonalInfluence do
  use Mix.Task

  @shortdoc "Runs the local interpersonal influence experiment"

  @moduledoc """
  Runs grounded nearby-presence and observed-action influence metrics.

      mix procession.metrics.local_interpersonal_influence
      mix procession.metrics.local_interpersonal_influence --cycles 128 --seed 41
  """

  alias Procession.Simulation.LocalInterpersonalInfluenceExperiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining, _invalid} =
      OptionParser.parse(args,
        strict: [cycles: :integer, seed: :integer]
      )

    result = LocalInterpersonalInfluenceExperiment.run(opts)
    Mix.shell().info(inspect(result, pretty: true, limit: :infinity))
  end
end