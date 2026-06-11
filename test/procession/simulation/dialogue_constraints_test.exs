defmodule Procession.Simulation.DialogueConstraintsTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DialogueConstraints

  describe "from_field_snapshot/1" do
    test "returns normal constraints for an empty field snapshot" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{},
        disclosure_boundaries: %{},
        trust_deltas: %{},
        private_concerns: [],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot) == %{
               intent: :normal_response,
               disclosure_level: :normal,
               tone: [:neutral],
               allowed_facts: [],
               forbidden_topics: [],
               field_pressure: :none
             }
    end

    test "returns guarded constraints for high Mira salience" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{mira: :high},
        disclosure_boundaries: %{mira: :high},
        trust_deltas: %{"player" => -1},
        private_concerns: [:player_asking_about_mira],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot) == %{
               intent: :guarded_deflection,
               disclosure_level: :minimal,
               tone: [:cautious, :neighborly],
               allowed_facts: [:narrow_public_identity, :narrow_relationship_denial],
               forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
               field_pressure: :sensitive_topic
             }
    end

    test "returns firm constraints for very high Mira salience" do
      snapshot = %{
        entity_id: "npc_tobin",
        topic_salience: %{mira: :very_high},
        disclosure_boundaries: %{mira: :very_high},
        trust_deltas: %{"player" => -2},
        private_concerns: [
          :player_asking_about_mira,
          :player_repeatedly_asking_about_mira
        ],
        presentations: []
      }

      assert DialogueConstraints.from_field_snapshot(snapshot) == %{
               intent: :firm_deflection,
               disclosure_level: :none,
               tone: [:guarded, :firm],
               allowed_facts: [:narrow_relationship_denial],
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
      assert DialogueConstraints.from_field_snapshot(%{}) == %{
               intent: :normal_response,
               disclosure_level: :normal,
               tone: [:neutral],
               allowed_facts: [],
               forbidden_topics: [],
               field_pressure: :none
             }

      assert DialogueConstraints.from_field_snapshot(nil) == %{
               intent: :normal_response,
               disclosure_level: :normal,
               tone: [:neutral],
               allowed_facts: [],
               forbidden_topics: [],
               field_pressure: :none
             }
    end
  end
end
