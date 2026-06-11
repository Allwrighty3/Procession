defmodule Procession.Simulation.PresentationDetectorTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.PresentationDetector

  describe "from_player_message/1" do
    test "detects Mira question presentations" do
      assert PresentationDetector.from_player_message("Who is Mira?") == %{
              source: "player",
              kind: :question,
              target: {:person, :mira},
              message_intent: :ask_public_identity,
              text: "Who is Mira?"
            }
    end

    test "detects Tobin question presentations" do
      assert PresentationDetector.from_player_message("What does Tobin know?") == %{
              source: "player",
              kind: :question,
              target: {:person, :tobin},
              message_intent: :general,
              text: "What does Tobin know?"
            }
    end

    test "detects general statements" do
      assert PresentationDetector.from_player_message("Hello there") == %{
              source: "player",
              kind: :statement,
              target: {:message, :general},
              message_intent: :general,
              text: "Hello there"
            }
    end

    test "trims only for kind detection while preserving original text" do
      assert PresentationDetector.from_player_message("  Who is Mira?  ") == %{
              source: "player",
              kind: :question,
              target: {:person, :mira},
              message_intent: :ask_public_identity,
              text: "  Who is Mira?  "
            }
    end

    test "detects relationship denial questions" do
      assert PresentationDetector.from_player_message("Is Mira your sister?") == %{
              source: "player",
              kind: :question,
              target: {:person, :mira},
              message_intent: :ask_relationship_denial,
              text: "Is Mira your sister?"
            }
    end

    test "detects location questions" do
      assert PresentationDetector.from_player_message("Where can I find Mira?") == %{
              source: "player",
              kind: :question,
              target: {:person, :mira},
              message_intent: :ask_location,
              text: "Where can I find Mira?"
            }
    end
  end
end
