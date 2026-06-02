defmodule Procession.AI.NPCInteraction.ResponseRealizerTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ResponseIntentBuilder
  alias Procession.AI.NPCInteraction.ResponseRealizer

  test "realizes self identity intent in first person" do
    assert {:ok, intent} =
             ResponseIntentBuilder.build(context(%{"message" => "Who are you?"}))

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response == "I'm Tobin, the merchant out by the crossroads."
  end

  test "realizes known entity intent without transferring roles" do
    assert {:ok, intent} =
             ResponseIntentBuilder.build(context(%{"message" => "Who is Mira?"}))

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response == "Mira is the innkeeper in Briar Village."
    refute response =~ "merchant"
    refute response =~ "crossroads"
  end

  test "realizes unknown entity intent without invented traits" do
    assert {:ok, intent} =
             ResponseIntentBuilder.build(context(%{"message" => "Who is Elandra?"}))

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response == "I don't know anyone named Elandra."
    refute response =~ "merchant"
    refute response =~ "innkeeper"
    refute response =~ "crossroads"
    refute response =~ "Briar Village"
  end

  test "realizes general uncertainty intent" do
    assert {:ok, intent} =
             ResponseIntentBuilder.build(context(%{"message" => "What is the weather?"}))

    assert {:ok, response} = ResponseRealizer.realize(intent)

    assert response == "I don't know enough to answer that."
  end

  test "rejects invalid intent" do
    assert {:error, :invalid_response_intent} = ResponseRealizer.realize(nil)
  end

  test "returns validator errors for structurally invalid intent" do
    assert {:error, failures} = ResponseRealizer.realize(%{})

    assert Enum.any?(failures, fn failure ->
             failure.code == :missing_required_field
           end)
  end

  defp context(overrides \\ %{}) do
    Map.merge(
      %{
        "known_entities" => [
          %{
            "id" => "npc_tobin",
            "name" => "Tobin",
            "type" => "npc",
            "role" => "merchant",
            "location" => "crossroads"
          },
          %{
            "id" => "npc_mira",
            "name" => "Mira",
            "type" => "npc",
            "role" => "innkeeper",
            "location" => "Briar Village"
          }
        ],
        "message" => "Who is Mira?",
        "target" => %{
          "id" => "npc_tobin",
          "name" => "Tobin",
          "type" => "npc",
          "role" => "merchant",
          "location" => "crossroads"
        }
      },
      overrides
    )
  end
end
