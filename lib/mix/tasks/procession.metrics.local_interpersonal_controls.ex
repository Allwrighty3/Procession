defmodule Mix.Tasks.Procession.Metrics.LocalInterpersonalControls do
  use Mix.Task

  @moduledoc "Runs grounded local interpersonal control scenarios."
  @shortdoc "Runs grounded local interpersonal control scenarios"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _, _} = OptionParser.parse(args, strict: [cycles: :integer, seed: :integer])
    result = Procession.Simulation.LocalInterpersonalControlsExperiment.run(opts)
    Mix.shell().info(inspect(result, pretty: true, limit: :infinity))
  end
end
