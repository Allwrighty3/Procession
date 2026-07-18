defmodule Mix.Tasks.Procession.Metrics.MotorPlasticityFactorial do
  use Mix.Task

  @shortdoc "Runs the motor-plasticity factorial comparison"

  alias Procession.Simulation.MotorPlasticityFactorialExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} = OptionParser.parse(args,
      strict: [samples: :integer, ticks: :integer, reversal_tick: :integer],
      aliases: [n: :samples, t: :ticks])

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    samples = Keyword.get(opts, :samples, 100)
    ticks = Keyword.get(opts, :ticks, 180)
    reversal_tick = Keyword.get(opts, :reversal_tick, div(ticks, 2))
    seeds = Enum.to_list(1..samples)

    results = Experiment.compare(ticks: ticks, reversal_tick: reversal_tick, seeds: seeds)

    Mix.shell().info("Motor-plasticity factorial metrics")
    Mix.shell().info("samples=#{samples} ticks=#{ticks} reversal_tick=#{reversal_tick}\n")
    Mix.shell().info(Experiment.report(results))
  end
end
