defmodule Mix.Tasks.Procession.Eval.NpcInteractionNaturalness do
  @moduledoc """
  Loads and scores local NPC interaction naturalness eval cases.

      mix procession.eval.npc_interaction_naturalness

  This task does not call AI. It scores stored naturalness eval case responses
  against deterministic surface and grounded-naturalness failure signals.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.NaturalnessEvalCaseLoader
  alias Procession.AI.NPCInteraction.NaturalnessEvalScorer

  @shortdoc "Scores NPC interaction naturalness eval cases"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case NaturalnessEvalCaseLoader.load_default() do
      {:ok, cases} ->
        run_eval(cases)

      {:error, reason} ->
        Mix.raise("Failed to load NPC interaction naturalness eval cases: #{inspect(reason)}")
    end
  end

  defp run_eval(cases) do
    summary = NaturalnessEvalScorer.score_cases(cases)

    Mix.shell().info("NPC interaction naturalness eval summary:")
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
