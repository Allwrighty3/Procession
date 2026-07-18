defmodule Mix.Tasks.Procession.Metrics.MotorCompetition do
  use Mix.Task

  @shortdoc "Runs emergent motor competition metrics"

  @moduledoc """
  Runs the motor competition reversal experiment with deterministic seeds.

      mix procession.metrics.motor_competition
      mix procession.metrics.motor_competition --samples 100 --ticks 180 --reversal-tick 90
  """

  alias Procession.Simulation.MotorCompetitionExperiment, as: Experiment

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, ticks: :integer, reversal_tick: :integer, first_seed: :integer],
        aliases: [n: :samples, t: :ticks]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    samples = positive!(Keyword.get(opts, :samples, 100), "samples")
    ticks = positive!(Keyword.get(opts, :ticks, 180), "ticks")
    reversal_tick = positive!(Keyword.get(opts, :reversal_tick, div(ticks, 2)), "reversal_tick")
    first_seed = Keyword.get(opts, :first_seed, 1)
    seeds = Enum.to_list(first_seed..(first_seed + samples - 1))

    results =
      Experiment.compare(
        ticks: ticks,
        reversal_tick: reversal_tick,
        seeds: seeds
      )

    Mix.shell().info("Motor competition metrics")
    Mix.shell().info(
      "samples=#{samples} ticks=#{ticks} reversal_tick=#{reversal_tick} " <>
        "seeds=#{first_seed}..#{first_seed + samples - 1}\n"
    )

    Mix.shell().info(Experiment.report(results))
  end

  defp positive!(value, _name) when is_integer(value) and value > 0, do: value
  defp positive!(_value, name), do: Mix.raise("#{name} must be a positive integer")
end
