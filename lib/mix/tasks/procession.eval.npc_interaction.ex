defmodule Mix.Tasks.Procession.Eval.NpcInteraction do
  @moduledoc """
  Loads or manually runs local NPC interaction eval cases.

  By default, this task only loads and lists eval cases:

      mix procession.eval.npc_interaction

  To run the cases through local Ollama manually:

      mix procession.eval.npc_interaction --ollama

  Default tests do not call Ollama.
  """

  use Mix.Task

  alias Procession.AI
  alias Procession.AI.NPCInteraction.EvalCaseLoader
  alias Procession.AI.NPCInteraction.EvalScorer
  alias Procession.AI.Ollama

  @shortdoc "Loads or runs NPC interaction eval cases"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _remaining_args, _invalid} =
      OptionParser.parse(args,
        strict: [
          ollama: :boolean,
          model: :string
        ]
      )

    case EvalCaseLoader.load_default() do
      {:ok, cases} ->
        if Keyword.get(opts, :ollama, false) do
          run_ollama_eval(cases, opts)
        else
          list_cases(cases)
        end

      {:error, reason} ->
        Mix.raise("Failed to load NPC interaction eval cases: #{inspect(reason)}")
    end
  end

  defp list_cases(cases) do
    Mix.shell().info("Loaded #{length(cases)} NPC interaction eval cases.")

    cases
    |> Enum.map(& &1["id"])
    |> Enum.each(fn id ->
      Mix.shell().info("- #{id}")
    end)
  end

  defp run_ollama_eval(cases, opts) do
    model = Keyword.get(opts, :model, "llama3.2:1b")

    Mix.shell().info(
      "Running #{length(cases)} NPC interaction eval cases with Ollama model #{model}."
    )

    responses_by_case_id =
      Enum.reduce(cases, %{}, fn eval_case, responses ->
        id = eval_case["id"]

        Mix.shell().info("")
        Mix.shell().info("Case: #{id}")
        Mix.shell().info("Message: #{eval_case["message"]}")

        prompt = prompt_for_eval_case(eval_case)

        response =
          case AI.generate(prompt, adapter: Ollama, model: model) do
            {:ok, text} ->
              Mix.shell().info("Response: #{text}")
              text

            {:error, reason} ->
              error_text = "[ollama_error: #{inspect(reason)}]"
              Mix.shell().info("Response: #{error_text}")
              error_text
          end

        Map.put(responses, id, response)
      end)

    summary = EvalScorer.score_cases(cases, responses_by_case_id)

    Mix.shell().info("")
    Mix.shell().info("NPC interaction eval summary:")
    Mix.shell().info("Total: #{summary.total}")
    Mix.shell().info("Passed: #{summary.passed}")
    Mix.shell().info("Failed: #{summary.failed}")

    summary.results
    |> Enum.reject(& &1.passed)
    |> Enum.each(fn result ->
      Mix.shell().info("")
      Mix.shell().info("Failed case: #{result.id}")

      Enum.each(result.failures, fn failure ->
        Mix.shell().info("- #{failure.message}")
      end)
    end)
  end

  defp prompt_for_eval_case(eval_case) do
    """
    You are responding as an NPC in a grounded RPG simulation.

    Target NPC ID: #{eval_case["target_id"]}
    Player message: #{eval_case["message"]}

    Constraints:
    - Answer only as the target NPC.
    - Do not claim to be another NPC.
    - Do not invent unknown people, locations, relationships, or current activities.
    - If the answer is not grounded, say you do not know.
    - Keep the response concise.

    Respond to the player now.
    """
  end
end
