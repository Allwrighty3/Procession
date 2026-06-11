defmodule Procession.Simulation.PresentationDetectorTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.PresentationDetector

  describe "from_player_message/1" do
    test "detects Mira question presentations with fallback keyword behavior" do
      assert PresentationDetector.from_player_message("Who is Mira?") == %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               target_name: nil,
               topic_key: :mira,
               message_intent: :ask_public_identity,
               text: "Who is Mira?"
             }
    end

    test "detects Tobin question presentations with fallback keyword behavior" do
      assert PresentationDetector.from_player_message("What does Tobin know?") == %{
               source: "player",
               kind: :question,
               target: {:person, :tobin},
               target_name: nil,
               topic_key: :tobin,
               message_intent: :general,
               text: "What does Tobin know?"
             }
    end

    test "detects general statements" do
      assert PresentationDetector.from_player_message("Hello there") == %{
               source: "player",
               kind: :statement,
               target: {:message, :general},
               target_name: nil,
               topic_key: :general,
               message_intent: :general,
               text: "Hello there"
             }
    end

    test "trims only for kind detection while preserving original text" do
      assert PresentationDetector.from_player_message("  Who is Mira?  ") == %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               target_name: nil,
               topic_key: :mira,
               message_intent: :ask_public_identity,
               text: "  Who is Mira?  "
             }
    end

    test "detects relationship denial questions" do
      assert PresentationDetector.from_player_message("Is Mira your sister?") == %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               target_name: nil,
               topic_key: :mira,
               message_intent: :ask_relationship_denial,
               text: "Is Mira your sister?"
             }
    end

    test "detects location questions" do
      assert PresentationDetector.from_player_message("Where can I find Mira?") == %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               target_name: nil,
               topic_key: :mira,
               message_intent: :ask_location,
               text: "Where can I find Mira?"
             }
    end
  end

  describe "from_player_message/2" do
    test "uses known people to produce entity-backed targets" do
      known_people = [
        %{id: "npc_mira", name: "Mira"},
        %{id: "npc_tobin", name: "Tobin"}
      ]

      assert PresentationDetector.from_player_message("Who is Mira?", known_people: known_people) == %{
               source: "player",
               kind: :question,
               target: {:person, "npc_mira"},
               target_name: "Mira",
               topic_key: :mira,
               message_intent: :ask_public_identity,
               text: "Who is Mira?"
             }
    end

    test "falls back when no known person matches" do
      known_people = [
        %{id: "npc_elin", name: "Elin"}
      ]

      assert PresentationDetector.from_player_message("Who is Mira?", known_people: known_people) == %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               target_name: nil,
               topic_key: :mira,
               message_intent: :ask_public_identity,
               text: "Who is Mira?"
             }
    end
  end
end
