defmodule Mix.Tasks.Procession.Metrics.SiblingSignalFollowup do
  use Mix.Task

  @shortdoc "Runs the active sibling-only developmental diagnostic"

  @active_conditions [
    :teacher_sibling_invisible,
    :teacher_sibling_visible,
    :teacher_sibling_signals,
    :no_teacher_sibling_visible,
    :no_teacher_sibling_signals
  ]

  @impl true
  def run(_args) do
    result = Procession.Simulation.SiblingSignalFollowupExperiment.run()

    lines =
      Enum.map(@active_conditions, fn condition ->
        summary = Map.fetch!(result.summary, condition)

        "#{condition}: baby=#{fmt(summary.baby_survival_rate)} " <>
          "participation=#{fmt(summary.participation_survival_rate)} " <>
          "withdrawal=#{fmt(summary.withdrawal_survival_rate)} " <>
          "pair=#{fmt(summary.pair_survival_rate)} " <>
          "self_intake=#{fmt(summary.mean_self_intake)} " <>
          "caregiver=#{fmt(summary.mean_caregiver_intake)} " <>
          "withdrawal_intake=#{fmt(summary.mean_withdrawal_intake)} " <>
          "follow=#{fmt(summary.follow_rate)} " <>
          "missed=#{fmt(summary.missed_intent_rate)} " <>
          "signals=#{summary.signal_attempts} " <>
          "useful=#{fmt(summary.useful_signal_rate)}"
      end)

    [
      "Active dependent sibling comparison",
      "solo baselines archived in docs/agent_council/experiments/archived_solo_dependent_learners.md",
      "WARNING: teacher_sibling_invisible is not a clean no-observation control yet; shared resources are mutated sequentially within a tick",
      "population=#{result.population} baby=#{result.baby_ticks} participation=#{result.participation_ticks} withdrawal=#{result.withdrawal_ticks}",
      "learning=#{result.learning_scale} execution=#{result.execution_model}",
      ""
      | lines
    ]
    |> Enum.join("\n")
    |> Mix.shell().info()
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
