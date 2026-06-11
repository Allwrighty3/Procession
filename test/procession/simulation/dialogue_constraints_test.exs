defmodule Procession.Simulation.DialogueConstraintsTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DialogueConstraints

  describe "from_field_snapshot/2" do
    test "returns normal constraints for an empty field snapshot" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{},
        topic_pressure_counts: %{},
        disclosure_boundaries: %{},
        trust_deltas: %{},
        private_concerns: [],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot, %{message_intent: :general}) == %{
               intent: :normal_response,
               response_shape: :open_response,
               disclosure_level: :normal,
               tone: [:neutral],
               allowed_facts: [],
               forbidden_topics: [],
               field_pressure: :none
             }
    end

    test "returns public identity constraints for first Mira identity question" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{mira: :high},
        topic_pressure_counts: %{mira: 1},
        disclosure_boundaries: %{mira: :high},
        trust_deltas: %{"player" => -1},
        private_concerns: [:player_asking_about_mira],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot, %{
               message_intent: :ask_public_identity
             }) == %{
               intent: :guarded_deflection,
               response_shape: :public_identity_then_question,
               disclosure_level: :minimal,
               tone: [:cautious, :neighborly],
               allowed_facts: [:narrow_public_identity],
               forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
               field_pressure: :sensitive_topic
             }
    end

    test "returns relationship denial constraints for first Mira relationship question" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{mira: :high},
        topic_pressure_counts: %{mira: 1},
        disclosure_boundaries: %{mira: :high},
        trust_deltas: %{"player" => -1},
        private_concerns: [:player_asking_about_mira],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot, %{
               message_intent: :ask_relationship_denial
             }) == %{
               intent: :guarded_deflection,
               response_shape: :relationship_denial_then_question,
               disclosure_level: :minimal,
               tone: [:cautious, :neighborly],
               allowed_facts: [:narrow_relationship_denial],
               forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
               field_pressure: :sensitive_topic
             }
    end

    test "returns location refusal constraints for Mira location question" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{mira: :high},
        topic_pressure_counts: %{mira: 1},
        disclosure_boundaries: %{mira: :high},
        trust_deltas: %{"player" => -1},
        private_concerns: [:player_asking_about_mira],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot, %{message_intent: :ask_location}) == %{
               intent: :firm_deflection,
               response_shape: :location_refusal,
               disclosure_level: :none,
               tone: [:guarded, :firm],
               allowed_facts: [],
               forbidden_topics: [
                 :mira_location,
                 :mira_private_history,
                 :mira_hidden_relationship,
                 :mira_current_activity
               ],
               field_pressure: :sensitive_location_request
             }
    end

    test "returns firm constraints for repeated Mira pressure" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{mira: :high},
        topic_pressure_counts: %{mira: 2},
        disclosure_boundaries: %{mira: :very_high},
        trust_deltas: %{"player" => -2},
        private_concerns: [
          :player_asking_about_mira,
          :player_repeatedly_asking_about_mira
        ],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot, %{
               message_intent: :ask_relationship_denial
             }) == %{
               intent: :firm_deflection,
               response_shape: :repeated_topic_boundary,
               disclosure_level: :none,
               tone: [:guarded, :firm],
               allowed_facts: [],
               forbidden_topics: [
                 :mira_location,
                 :mira_private_history,
                 :mira_hidden_relationship,
                 :mira_current_activity
               ],
               field_pressure: :repeated_sensitive_topic
             }
    end

    test "returns normal constraints for malformed snapshots" do
      assert DialogueConstraints.from_field_snapshot(%{}, %{message_intent: :ask_location}) == %{
               intent: :normal_response,
               response_shape: :open_response,
               disclosure_level: :normal,
               tone: [:neutral],
               allowed_facts: [],
               forbidden_topics: [],
               field_pressure: :none
             }

      assert DialogueConstraints.from_field_snapshot(nil, %{message_intent: :ask_location}) == %{
               intent: :normal_response,
               response_shape: :open_response,
               disclosure_level: :normal,
               tone: [:neutral],
               allowed_facts: [],
               forbidden_topics: [],
               field_pressure: :none
             }
    end
  end

  describe "from_field_snapshot/1" do
    test "keeps backward-compatible default presentation behavior" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{mira: :high},
        topic_pressure_counts: %{mira: 1},
        disclosure_boundaries: %{mira: :high},
        trust_deltas: %{"player" => -1},
        private_concerns: [:player_asking_about_mira],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot).response_shape == :ask_why
    end
  end
end
