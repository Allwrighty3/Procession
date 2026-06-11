defmodule Procession.Simulation.PresentationDetectorTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.PresentationDetector

  describe "from_player_message/1" do
    test "detects Mira question presentations" do
      assert PresentationDetector.from_player_message("Who is Mira?") == %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               text: "Who is Mira?"
             }
    end

    test "detects Tobin question presentations" do
      assert PresentationDetector.from_player_message("What does Tobin know?") == %{
               source: "player",
               kind: :question,
               target: {:person, :tobin},
               text: "What does Tobin know?"
             }
    end

    test "detects general statements" do
      assert PresentationDetector.from_player_message("Hello there") == %{
               source: "player",
               kind: :statement,
               target: {:message, :general},
               text: "Hello there"
             }
    end

    test "trims only for kind detection while preserving original text" do
      assert PresentationDetector.from_player_message("  Who is Mira?  ") == %{
               source: "player",
               kind: :question,
               target: {:person, :mira},
               text: "  Who is Mira?  "
             }
    end
  end
end
