defmodule Procession.Simulation.InternalFieldTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.InternalField

  describe "new/1" do
    test "creates an empty internal field for an individual" do
      field = InternalField.new("npc_tobin")

      assert InternalField.snapshot(field) == %{
               entity_id: "npc_tobin",
               topic_salience: %{},
               topic_pressure_counts: %{},
               disclosure_boundaries: %{},
               trust_deltas: %{},
               private_concerns: [],
               presentations: []
             }
    end
  end

  describe "apply_presentation/2" do
    test "a Mira-related question raises salience and disclosure boundary" do
      field =
        "npc_tobin"
        |> InternalField.new()
        |> InternalField.apply_presentation(%{
          source: "player",
          kind: :question,
          target: {:person, :mira},
          text: "Who's Mira?"
        })

      snapshot = InternalField.snapshot(field)

      assert snapshot.entity_id == "npc_tobin"
      assert snapshot.topic_salience[:mira] == :high
      assert snapshot.topic_pressure_counts[:mira] == 1
      assert snapshot.disclosure_boundaries[:mira] == :high
      assert snapshot.trust_deltas["player"] == -1
      assert snapshot.private_concerns == [:player_asking_about_mira]

      assert snapshot.presentations == [
               %{
                 source: "player",
                 kind: :question,
                 target: {:person, :mira},
                 text: "Who's Mira?"
               }
             ]
    end

    test "repeated Mira-related questions intensify the private field" do
      field =
        "npc_tobin"
        |> InternalField.new()
        |> InternalField.apply_presentation(%{
          source: "player",
          kind: :question,
          target: {:person, :mira},
          text: "Who's Mira?"
        })
        |> InternalField.apply_presentation(%{
          source: "player",
          kind: :question,
          target: {:person, :mira},
          text: "Is Mira your sister?"
        })

      snapshot = InternalField.snapshot(field)

      assert snapshot.entity_id == "npc_tobin"
      assert snapshot.topic_salience[:mira] == :high
      assert snapshot.topic_pressure_counts[:mira] == 2
      assert snapshot.disclosure_boundaries[:mira] == :very_high
      assert snapshot.trust_deltas["player"] == -2

      assert snapshot.private_concerns == [
               :player_asking_about_mira,
               :player_repeatedly_asking_about_mira
             ]

      assert snapshot.presentations == [
               %{
                 source: "player",
                 kind: :question,
                 target: {:person, :mira},
                 text: "Who's Mira?"
               },
               %{
                 source: "player",
                 kind: :question,
                 target: {:person, :mira},
                 text: "Is Mira your sister?"
               }
             ]
    end

    test "unrelated presentations are recorded without Mira-specific modulation" do
      field =
        "npc_tobin"
        |> InternalField.new()
        |> InternalField.apply_presentation(%{
          source: "player",
          kind: :question,
          target: {:topic, :weather},
          text: "Nice weather?"
        })

      snapshot = InternalField.snapshot(field)

      assert snapshot.entity_id == "npc_tobin"
      assert snapshot.topic_salience == %{}
      assert snapshot.topic_pressure_counts == %{}
      assert snapshot.disclosure_boundaries == %{}
      assert snapshot.trust_deltas == %{}
      assert snapshot.private_concerns == []

      assert snapshot.presentations == [
               %{
                 source: "player",
                 kind: :question,
                 target: {:topic, :weather},
                 text: "Nice weather?"
               }
             ]
    end

    test "entity-backed Mira presentations use topic key for field modulation" do
      field =
        "npc_tobin"
        |> InternalField.new()
        |> InternalField.apply_presentation(%{
          source: "player",
          kind: :question,
          target: {:person, "npc_mira"},
          target_name: "Mira",
          topic_key: :mira,
          message_intent: :ask_public_identity,
          text: "Who is Mira?"
        })

      snapshot = InternalField.snapshot(field)

      assert snapshot.topic_salience[:mira] == :high
      assert snapshot.topic_pressure_counts[:mira] == 1
      assert snapshot.disclosure_boundaries[:mira] == :high
    end

    test "non-Mira topic keys use general field mechanics" do
      field =
        "npc_mira"
        |> InternalField.new()
        |> InternalField.apply_presentation(%{
          source: "player",
          kind: :question,
          target: {:person, "npc_tobin"},
          target_name: "Tobin",
          topic_key: :tobin,
          message_intent: :general,
          text: "What does Tobin know?"
        })
        |> InternalField.apply_presentation(%{
          source: "player",
          kind: :question,
          target: {:person, "npc_tobin"},
          target_name: "Tobin",
          topic_key: :tobin,
          message_intent: :general,
          text: "Where is Tobin?"
        })

      snapshot = InternalField.snapshot(field)

      assert snapshot.topic_salience[:tobin] == :high
      assert snapshot.topic_pressure_counts[:tobin] == 2
      assert snapshot.disclosure_boundaries[:tobin] == :very_high
      assert snapshot.trust_deltas["player"] == -2

      assert snapshot.private_concerns == [
               :player_asking_about_tobin,
               :player_repeatedly_asking_about_tobin
             ]
    end

    test "general topic presentations are recorded without field pressure" do
      field =
        "npc_tobin"
        |> InternalField.new()
        |> InternalField.apply_presentation(%{
          source: "player",
          kind: :statement,
          target: {:message, :general},
          target_name: nil,
          topic_key: :general,
          message_intent: :general,
          text: "Hello there"
        })

      snapshot = InternalField.snapshot(field)

      assert snapshot.topic_salience == %{}
      assert snapshot.topic_pressure_counts == %{}
      assert snapshot.disclosure_boundaries == %{}
      assert snapshot.trust_deltas == %{}
      assert snapshot.private_concerns == []
      assert length(snapshot.presentations) == 1
    end
  end
end
