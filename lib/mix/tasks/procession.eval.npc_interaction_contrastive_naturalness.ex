defmodule Mix.Tasks.Procession.Eval.NpcInteractionContrastiveNaturalness do
  @moduledoc """
  Loads and validates local NPC interaction contrastive naturalness eval cases.

      mix procession.eval.npc_interaction_contrastive_naturalness

  This task does not call AI. It validates stored contrastive naturalness cases
  so they can be used later for preference evaluation, training export, or model comparison.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.ContrastiveNaturalnessEvalScorer

  @shortdoc "Validates NPC interaction contrastive naturalness eval cases"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case ContrastiveNaturalnessEvalCaseLoader.load_default() do
      {:ok, cases} ->
        run_eval(cases)

      {:error, reason} ->
        Mix.raise(
          "Failed to load NPC interaction contrastive naturalness eval cases: #{inspect(reason)}"
        )
    end
  end

  defp run_eval(cases) do
    summary = ContrastiveNaturalnessEvalScorer.score_cases(cases)

    Mix.shell().info("NPC interaction contrastive naturalness eval summary:")
    Mix.shell().info("Total: #{summary.total}")
    Mix.shell().info("Passed: #{summary.passed}")
    Mix.shell().info("Failed: #{summary.failed}")

    summary.results
    |> Enum.reject(& &1.passed)
    |> Enum.each(fn result ->
      Mix.shell().info("")
      Mix.shell().info("Failed case: #{result.id}")

      if result.category do
        Mix.shell().info("Category: #{result.category}")
      end

      Enum.each(result.failures, fn failure ->
        Mix.shell().info("- #{failure.message}")
      end)
    end)
  end
end
