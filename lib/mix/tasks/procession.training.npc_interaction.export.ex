defmodule Mix.Tasks.Procession.Training.NpcInteraction.Export do
  @moduledoc """
  Exports the local NPC interaction training corpus.

      mix procession.training.npc_interaction.export

  The export is derived from inert training examples and is intended for local
  training/fine-tuning tooling. It does not call Ollama, mutate simulation state,
  create entity memory, or create behavior metadata.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.TrainingExampleLoader

  @shortdoc "Exports NPC interaction training examples"
  @default_output_path "priv/training/exports/npc_interaction_training_export.jsonl"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining_args, _invalid} =
      OptionParser.parse(args,
        strict: [
          output: :string
        ]
      )

    output_path = Keyword.get(opts, :output, @default_output_path)

    case TrainingExampleLoader.load_default() do
      {:ok, examples} ->
        export_examples(examples, output_path)

      {:error, reason} ->
        Mix.raise("Failed to export NPC interaction training corpus: #{inspect(reason)}")
    end
  end

  defp export_examples(examples, output_path) do
    output_path
    |> Path.dirname()
    |> File.mkdir_p!()

    output =
      examples
      |> Enum.map(&export_example/1)
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    File.write!(output_path, output <> "\n")

    Mix.shell().info("Exported #{length(examples)} NPC interaction training examples.")
    Mix.shell().info("Output: #{output_path}")
  end

  defp export_example(example) do
    %{
      "id" => example["id"],
      "task" => example["task"],
      "input" => %{
        "context" => example["context"]
      },
      "output" => %{
        "expected_response" => example["expected_response"]
      },
      "metadata" => %{
        "rejected_responses" => example["rejected_responses"],
        "failure_tags" => example["failure_tags"],
        "notes" => example["notes"],
        "non_authoritative" => true
      }
    }
  end
end
