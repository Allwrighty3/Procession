defmodule Mix.Tasks.Procession.Demo.NpcInteractionPipeline do
  @moduledoc """
  Runs a small deterministic NPC interaction pipeline demo.

      mix procession.demo.npc_interaction_pipeline

  This demo builds response intents from grounded context and realizes them into
  safe text without calling AI.
  """

  use Mix.Task

  alias Procession.AI.NPCInteraction.InteractionPipeline

  @shortdoc "Runs deterministic NPC interaction pipeline demo"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    demo_cases()
    |> Enum.each(&run_case/1)
  end

  defp run_case(%{"id" => id, "context" => context}) do
    Mix.shell().info("")
    Mix.shell().info("Case: #{id}")
    Mix.shell().info("Message: #{context["message"]}")
    Mix.shell().info("Target: #{context["target"]["id"]}")

    case InteractionPipeline.respond(context) do
      {:ok, result} ->
        Mix.shell().info("Dialogue act: #{result.intent["dialogue_act"]}")
        Mix.shell().info("Response: #{result.response}")

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
