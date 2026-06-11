defmodule Procession.Simulation.PresentationDetectorTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.PresentationDetector

  describe "from_player_message/1" do
    test "detects Mira question presentations with fallback keyword behavior" do
      presentation = PresentationDetector.from_player_message("Who is Mira?")

      assert_presentation(presentation,
        source: "player",
        kind: :question,
        target: {:person, :mira},
        target_name: nil,
        target_public_facts: %{},
        topic_key: :mira,
        message_intent: :ask_public_identity,
        text: "Who is Mira?"
      )
    end

    test "detects Tobin question presentations with fallback keyword behavior" do
      presentation = PresentationDetector.from_player_message("What does Tobin know?")

      assert_presentation(presentation,
        source: "player",
        kind: :question,
        target: {:person, :tobin},
        target_name: nil,
        target_public_facts: %{},
        topic_key: :tobin,
        message_intent: :general,
        text: "What does Tobin know?"
      )
    end

    test "detects general statements" do
      presentation = PresentationDetector.from_player_message("Hello there")

      assert_presentation(presentation,
        source: "player",
        kind: :statement,
        target: {:message, :general},
        target_name: nil,
        target_public_facts: %{},
        topic_key: :general,
        message_intent: :general,
        text: "Hello there"
      )
    end

    test "trims only for kind detection while preserving original text" do
      presentation = PresentationDetector.from_player_message("  Who is Mira?  ")

      assert_presentation(presentation,
        source: "player",
        kind: :question,
        target: {:person, :mira},
        target_name: nil,
        target_public_facts: %{},
        topic_key: :mira,
        message_intent: :ask_public_identity,
        text: "  Who is Mira?  "
      )
    end

    test "detects relationship denial questions with fallback keyword behavior" do
      presentation = PresentationDetector.from_player_message("Is Mira your sister?")

      assert_presentation(presentation,
        source: "player",
        kind: :question,
        target: {:person, :mira},
        target_name: nil,
        target_public_facts: %{},
        topic_key: :mira,
        message_intent: :ask_relationship_denial,
        text: "Is Mira your sister?"
      )
    end

    test "detects location questions with fallback keyword behavior" do
      presentation = PresentationDetector.from_player_message("Where can I find Mira?")

      assert_presentation(presentation,
        source: "player",
        kind: :question,
        target: {:person, :mira},
        target_name: nil,
        target_public_facts: %{},
        topic_key: :mira,
        message_intent: :ask_location,
        text: "Where can I find Mira?"
      )
    end
  end

  describe "from_player_message/2" do
    test "uses known people to produce entity-backed targets" do
      presentation =
        PresentationDetector.from_player_message("Who is Mira?", known_people: known_people())

      assert_presentation(presentation,
        source: "player",
        kind: :question,
        target: {:person, "npc_mira"},
        target_name: "Mira",
        target_public_facts: %{role: "innkeeper"},
        topic_key: :mira,
        message_intent: :ask_public_identity,
        text: "Who is Mira?"
      )
    end

    test "infers public identity intent for any known person" do
      known_people = known_people()

      tobin =
        PresentationDetector.from_player_message("Who is Tobin?", known_people: known_people)

      assert_presentation(tobin,
        source: "player",
        kind: :question,
        target: {:person, "npc_tobin"},
        target_name: "Tobin",
        target_public_facts: %{role: "merchant"},
        topic_key: :tobin,
        message_intent: :ask_public_identity,
        text: "Who is Tobin?"
      )

      elin =
        PresentationDetector.from_player_message("Who's Elin?", known_people: known_people)

      assert_presentation(elin,
        source: "player",
        kind: :question,
        target: {:person, "npc_elin"},
        target_name: "Elin",
        target_public_facts: %{role: "scout"},
        topic_key: :elin,
        message_intent: :ask_public_identity,
        text: "Who's Elin?"
      )
    end

    test "infers location intent for any known person" do
      known_people = known_people()

      tobin =
        PresentationDetector.from_player_message("Where is Tobin?", known_people: known_people)

      assert_presentation(tobin,
        source: "player",
        kind: :question,
        target: {:person, "npc_tobin"},
        target_name: "Tobin",
        target_public_facts: %{role: "merchant"},
        topic_key: :tobin,
        message_intent: :ask_location,
        text: "Where is Tobin?"
      )

      elin =
        PresentationDetector.from_player_message("Where can I find Elin?",
          known_people: known_people
        )

      assert_presentation(elin,
        source: "player",
        kind: :question,
        target: {:person, "npc_elin"},
        target_name: "Elin",
        target_public_facts: %{role: "scout"},
        topic_key: :elin,
        message_intent: :ask_location,
        text: "Where can I find Elin?"
      )
    end

    test "infers relationship denial intent for any known person" do
      known_people = known_people()

      mira =
        PresentationDetector.from_player_message("Is Mira your sister?",
          known_people: known_people
        )

      assert_presentation(mira,
        source: "player",
        kind: :question,
        target: {:person, "npc_mira"},
        target_name: "Mira",
        target_public_facts: %{role: "innkeeper"},
        topic_key: :mira,
        message_intent: :ask_relationship_denial,
        text: "Is Mira your sister?"
      )

      tobin =
        PresentationDetector.from_player_message("Is Tobin your brother?",
          known_people: known_people
        )

      assert_presentation(tobin,
        source: "player",
        kind: :question,
        target: {:person, "npc_tobin"},
        target_name: "Tobin",
        target_public_facts: %{role: "merchant"},
        topic_key: :tobin,
        message_intent: :ask_relationship_denial,
        text: "Is Tobin your brother?"
      )
    end

    test "falls back when no known person matches" do
      known_people = [
        %{id: "npc_elin", name: "Elin", public_facts: %{role: "scout"}}
      ]

      presentation =
        PresentationDetector.from_player_message("Who is Mira?", known_people: known_people)

      assert_presentation(presentation,
        source: "player",
        kind: :question,
        target: {:person, :mira},
        target_name: nil,
        target_public_facts: %{},
        topic_key: :mira,
        message_intent: :ask_public_identity,
        text: "Who is Mira?"
      )
    end
  end

  defp assert_presentation(presentation, expected) do
    Enum.each(expected, fn {key, value} ->
      assert Map.fetch!(presentation, key) == value
    end)
  end

  defp known_people do
    [
      %{id: "npc_mira", name: "Mira", public_facts: %{role: "innkeeper"}},
      %{id: "npc_tobin", name: "Tobin", public_facts: %{role: "merchant"}},
      %{id: "npc_elin", name: "Elin", public_facts: %{role: "scout"}}
    ]
  end
end
