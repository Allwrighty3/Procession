defmodule Mix.Tasks.Procession.Training.NpcInteraction.Validate do
  @moduledoc """
  Validates the local NPC interaction training corpus.

      mix procession.training.npc_interaction.validate

  This task only loads and validates inert JSONL training data. It does not call
  Ollama, mutate simulation state, create entity memory, or create behavior
  metadata.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.TrainingExampleLoader

  @shortdoc "Validates NPC interaction training examples"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    case TrainingExampleLoader.load_default() do
      {:ok, examples} ->
        Mix.shell().info("Loaded #{length(examples)} NPC interaction training examples.")
        Mix.shell().info("NPC interaction training corpus is valid.")

      {:error, reason} ->
        Mix.raise("Failed to validate NPC interaction training corpus: #{inspect(reason)}")
    end
  end
end
