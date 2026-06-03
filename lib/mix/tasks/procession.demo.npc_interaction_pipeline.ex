defmodule Mix.Tasks.Procession.Demo.NpcInteractionPipeline do
  @moduledoc """
  Runs a small deterministic NPC interaction pipeline demo.

      mix procession.demo.npc_interaction_pipeline

  This demo builds response intents from grounded context and realizes them into
  safe text without calling AI.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.InteractionPipeline

  defmodule SafeExpressionAdapter do
    def generate(_prompt, _opts) do
      {:ok, "Mira keeps the inn in Briar Village."}
    end
  end

  defmodule UnsafeExpressionAdapter do
    def generate(_prompt, _opts) do
      {:ok, "Elandra is a merchant at the crossroads."}
    end
  end

  @shortdoc "Runs deterministic NPC interaction pipeline demo"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    demo_cases()
    |> Enum.each(&run_case/1)
  end

  defp run_case(%{"id" => id, "context" => context} = demo_case) do
    Mix.shell().info("")
    Mix.shell().info("Case: #{id}")
    Mix.shell().info("Message: #{context["message"]}")
    Mix.shell().info("Target: #{context["target"]["id"]}")

    opts =
      cond do
        Map.has_key?(demo_case, "candidate_response") ->
          candidate_response = Map.fetch!(demo_case, "candidate_response")
          Mix.shell().info("Candidate: #{inspect(candidate_response)}")
          [candidate_response: candidate_response]

        Map.get(demo_case, "expression_adapter") == :safe ->
          Mix.shell().info("Expression adapter: safe")
          [expression_adapter: SafeExpressionAdapter]

        Map.get(demo_case, "expression_adapter") == :unsafe ->
          Mix.shell().info("Expression adapter: unsafe")
          [expression_adapter: UnsafeExpressionAdapter]

        true ->
          []
      end

    case InteractionPipeline.respond(context, opts) do
      {:ok, result} ->
        Mix.shell().info("Dialogue act: #{result.intent["dialogue_act"]}")
        Mix.shell().info("Response source: #{result.response_source}")
        Mix.shell().info("Response: #{result.response}")

        if Map.get(result, :expression_candidate_response) do
          Mix.shell().info("Expression candidate: #{result.expression_candidate_response}")
        end

        if Map.get(result, :expression_adapter_error) do
          Mix.shell().info(
            "Expression adapter error: #{inspect(result.expression_adapter_error)}"
          )
        end

        if result.validation_failures != [] do
          Mix.shell().info("Fallback: #{result.fallback_response}")
          Mix.shell().info("Validation failures: #{inspect(result.validation_failures)}")
        end

      {:error, reason} ->
        Mix.shell().info("Error: #{inspect(reason)}")
    end
  end

  defp demo_cases do
    [
      %{
        "id" => "tobin_about_mira",
        "context" => context("npc_tobin", "Who is Mira?")
      },
      %{
        "id" => "tobin_self_identity",
        "context" => context("npc_tobin", "Who are you?")
      },
      %{
        "id" => "tobin_unknown_elandra",
        "context" => context("npc_tobin", "Who is Elandra?")
      },
      %{
        "id" => "tobin_not_innkeeper",
        "context" => context("npc_tobin", "Do you run the inn?")
      },
      %{
        "id" => "tobin_mira_not_sister",
        "context" => context("npc_tobin", "Is Mira your sister?")
      },
      %{
        "id" => "tobin_mira_current_activity_unknown",
        "context" => context("npc_tobin", "Is Mira serving drinks right now?")
      },
      %{
        "id" => "tobin_where_is_mira",
        "context" => context("npc_tobin", "Where is Mira?")
      },
      %{
        "id" => "safe_candidate_about_mira",
        "context" => context("npc_tobin", "Who is Mira?"),
        "candidate_response" => "Mira keeps the inn in Briar Village."
      },
      %{
        "id" => "unsafe_candidate_unknown_elandra",
        "context" => context("npc_tobin", "Who is Elandra?"),
        "candidate_response" => "Elandra is a merchant at the crossroads."
      },
      %{
        "id" => "safe_expression_adapter_about_mira",
        "context" => context("npc_tobin", "Who is Mira?"),
        "expression_adapter" => :safe
      },
      %{
        "id" => "unsafe_expression_adapter_unknown_elandra",
        "context" => context("npc_tobin", "Who is Elandra?"),
        "expression_adapter" => :unsafe
      }
    ]
  end

  defp context(target_id, message) do
    target = entity(target_id)

    %{
      "known_entities" => [
        entity("npc_tobin"),
        entity("npc_mira")
      ],
      "message" => message,
      "target" => target
    }
  end

  defp entity("npc_tobin") do
    %{
      "id" => "npc_tobin",
      "name" => "Tobin",
      "type" => "npc",
      "role" => "merchant",
      "location" => "crossroads"
    }
  end

  defp entity("npc_mira") do
    %{
      "id" => "npc_mira",
      "name" => "Mira",
      "type" => "npc",
      "role" => "innkeeper",
      "location" => "Briar Village"
    }
  end
end
