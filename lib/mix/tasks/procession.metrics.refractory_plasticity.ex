defmodule Mix.Tasks.Procession.Metrics.RefractoryPlasticity do
  use Mix.Task

  @shortdoc "Runs refractory motor and field plasticity metrics"

  alias Procession.Simulation.RefractoryPlasticityExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, reversal_tick: :integer],
        aliases: [n: :samples, t: :ticks]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    samples = positive!(Keyword.get(opts, :samples, 100), "samples")
    ticks = positive!(Keyword.get(opts, :ticks, 180), "ticks")
    reversal_tick = positive!(Keyword.get(opts, :reversal_tick, div(ticks, 2)), "reversal_tick")

    results =
      Experiment.compare(
        ticks: ticks,
        reversal_tick: reversal_tick,
        seeds: Enum.to_list(1..samples)
      )

    Mix.shell().info("Refractory plasticity metrics")
    Mix.shell().info("samples=#{samples} ticks=#{ticks} reversal_tick=#{reversal_tick}\n")
    Mix.shell().info(Experiment.report(results))
  end

  defp positive!(value, _name) when is_integer(value) and value > 0, do: value
  defp positive!(_value, name), do: Mix.raise("#{name} must be a positive integer")
end
