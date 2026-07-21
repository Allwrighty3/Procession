defmodule Procession.Simulation.HomeForagingEmergentMotorTimescaleMatrix do
  @moduledoc """
  Runs the emergent-motor taught comparison across short and ultra-slow timescales.

  The underlying learner and caregiver mechanics are unchanged. This module varies only
  duration and physical pressure so the original short control remains visible beside
  the ultra-slow developmental conditions.
  """

  alias Procession.Simulation.HomeForagingEmergentMotorControlExperiment, as: Experiment

  @profiles [
    {:short_full_pressure,
     [max_ticks: 320, teaching_ticks: 240, vitality: 0.72, metabolic: 0.010,
      warmth_loss: 0.018, cold_cost: 0.006, action_scale: 1.0]},
    {:ultra_slow_forgiving,
     [max_ticks: 8_000, teaching_ticks: 5_000, vitality: 0.995, metabolic: 0.00035,
      warmth_loss: 0.0005, cold_cost: 0.00015, action_scale: 0.04]},
    {:ultra_slow_moderate,
     [max_ticks: 8_000, teaching_ticks: 5_000, vitality: 0.99, metabolic: 0.00065,
      warmth_loss: 0.0009, cold_cost: 0.00030, action_scale: 0.075]}
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 24)
    seed = Keyword.get(opts, :seed, 1)

    results =
      Map.new(@profiles, fn {profile, profile_opts} ->
        run_opts = [population: population, seed: seed] ++ profile_opts
        {profile, Experiment.run(run_opts)}
      end)

    %{population: population, seed: seed, results: results}
  end

  def report(result) do
    header = [
      "Emergent-motor developmental timescale matrix",
      "paired seeds and bodies within every profile",
      "short/full-pressure baseline plus ultra-slow forgiving and moderate-pressure cohorts"
    ]

    lines =
      Enum.flat_map(@profiles, fn {profile, _opts} ->
        experiment = Map.fetch!(result.results, profile)

        [:no_teacher, :taught]
        |> Enum.map(fn condition ->
          summary = Map.fetch!(experiment.summary, condition)

          "#{profile}/#{condition}: survived=#{summary.survived}/#{result.population} " <>
            "withdrawal=#{summary.survived_withdrawal}/#{result.population} " <>
            "death=#{fmt(summary.median_death_tick)} displaced=#{summary.displaced}/#{result.population} " <>
            "food=#{summary.reached_food}/#{result.population} collected=#{summary.collected}/#{result.population} " <>
            "home=#{summary.returned_home}/#{result.population} consumed=#{summary.consumed}/#{result.population} " <>
            "stable=#{fmt(summary.stable_patterns)} rate=#{fmt(summary.displacement_rate)} " <>
            "coordination=#{fmt(summary.strongest_coordination)} assistance=#{fmt(summary.assistance_rate)}"
        end)
      end)

    Enum.join(header ++ lines, "\n")
  end

  def profiles, do: Enum.map(@profiles, &elem(&1, 0))

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
