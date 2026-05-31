defmodule Mix.Tasks.Procession.Eval.NpcInteraction do
  @moduledoc """
  Loads the local NPC interaction eval cases.

  This is a manual eval entry point. It does not call Ollama by default.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.EvalCaseLoader

  @shortdoc "Loads NPC interaction eval cases"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case EvalCaseLoader.load_default() do
      {:ok, cases} ->
        Mix.shell().info("Loaded #{length(cases)} NPC interaction eval cases.")

        cases
        |> Enum.map(& &1["id"])
        |> Enum.each(fn id ->
          Mix.shell().info("- #{id}")
        end)

      {:error, reason} ->
        Mix.raise("Failed to load NPC interaction eval cases: #{inspect(reason)}")
    end
  end
end
