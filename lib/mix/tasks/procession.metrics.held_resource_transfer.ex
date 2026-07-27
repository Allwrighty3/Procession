defmodule Mix.Tasks.Procession.Metrics.HeldResourceTransfer do
  use Mix.Task
  @shortdoc "Runs the held body-to-body resource transfer experiment"

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    {opts, _, _} = OptionParser.parse(args, strict: [requested: :float, limit: :float])
    result = Procession.Simulation.HeldResourceTransferExperiment.run(opts)
    Mix.shell().info(inspect(result, pretty: true, limit: :infinity))
  end
end
