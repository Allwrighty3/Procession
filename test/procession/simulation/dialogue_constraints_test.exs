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

      constraints = DialogueConstraints.from_field_snapshot(snapshot, %{message_intent: :general})

      assert_constraints(constraints,
        intent: :normal_response,
        response_shape: :open_response,
        disclosure_level: :normal,
        tone: [:neutral],
        allowed_facts: [],
        forbidden_topics: [],
        field_pressure: :none,
        topic_key: :general,
        target_name: nil,
        target_public_facts: %{}
      )
    end

    test "returns public identity constraints for first Mira identity question" do
      snapshot = mira_snapshot(pressure_count: 1)

      constraints =
        DialogueConstraints.from_field_snapshot(snapshot, %{
          topic_key: :mira,
          target_name: "Mira",
          target_public_facts: %{role: "innkeeper"},
          message_intent: :ask_public_identity
        })

      assert_constraints(constraints,
        intent: :guarded_deflection,
        response_shape: :public_identity_then_question,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [:narrow_public_identity],
        forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
        field_pressure: :sensitive_topic,
        topic_key: :mira,
        target_name: "Mira",
        target_public_facts: %{role: "innkeeper"}
      )
    end

    test "returns relationship denial constraints for first Mira relationship question" do
      snapshot = mira_snapshot(pressure_count: 1)

      constraints =
        DialogueConstraints.from_field_snapshot(snapshot, %{
          topic_key: :mira,
          target_name: "Mira",
          message_intent: :ask_relationship_denial
        })

      assert_constraints(constraints,
        intent: :guarded_deflection,
        response_shape: :relationship_denial_then_question,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [:narrow_relationship_denial],
        forbidden_topics: [:mira_location, :mira_private_history, :mira_hidden_relationship],
        field_pressure: :sensitive_topic,
        topic_key: :mira,
        target_name: "Mira",
        target_public_facts: %{}
      )
    end

    test "returns location refusal constraints for Mira location question" do
      snapshot = mira_snapshot(pressure_count: 1)

      constraints =
        DialogueConstraints.from_field_snapshot(snapshot, %{
          topic_key: :mira,
          target_name: "Mira",
          message_intent: :ask_location
        })

      assert_constraints(constraints,
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
        field_pressure: :sensitive_location_request,
        topic_key: :mira,
        target_name: "Mira",
        target_public_facts: %{}
      )
    end

    test "returns firm constraints for repeated Mira pressure" do
      snapshot = mira_snapshot(pressure_count: 2)

      constraints =
        DialogueConstraints.from_field_snapshot(snapshot, %{
          topic_key: :mira,
          target_name: "Mira",
          message_intent: :ask_relationship_denial
        })

      assert_constraints(constraints,
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
        field_pressure: :repeated_sensitive_topic,
        topic_key: :mira,
        target_name: "Mira",
        target_public_facts: %{}
      )
    end

    test "returns generic sensitive-topic constraints for non-Mira topics" do
      snapshot = tobin_snapshot(pressure_count: 1)

      constraints =
        DialogueConstraints.from_field_snapshot(snapshot, %{
          topic_key: :tobin,
          target_name: "Tobin",
          message_intent: :general
        })

      assert_constraints(constraints,
        intent: :guarded_deflection,
        response_shape: :ask_why,
        disclosure_level: :minimal,
        tone: [:cautious, :neighborly],
        allowed_facts: [],
        forbidden_topics: [
          :tobin_location,
          :tobin_private_history,
          :tobin_hidden_relationship
        ],
        field_pressure: :sensitive_topic,
        topic_key: :tobin,
        target_name: "Tobin",
        target_public_facts: %{}
      )
    end

    test "returns generic repeated-topic constraints for non-Mira topics" do
      snapshot = tobin_snapshot(pressure_count: 2)

      constraints =
        DialogueConstraints.from_field_snapshot(snapshot, %{
          topic_key: :tobin,
          target_name: "Tobin",
          message_intent: :general
        })

      assert_constraints(constraints,
        intent: :firm_deflection,
        response_shape: :repeated_topic_boundary,
        disclosure_level: :none,
        tone: [:guarded, :firm],
        allowed_facts: [],
        forbidden_topics: [
          :tobin_location,
          :tobin_private_history,
          :tobin_hidden_relationship,
          :tobin_current_activity
        ],
        field_pressure: :repeated_sensitive_topic,
        topic_key: :tobin,
        target_name: "Tobin",
        target_public_facts: %{}
      )
    end

    test "returns generic location refusal constraints for non-Mira topics" do
      snapshot = tobin_snapshot(pressure_count: 1)

      constraints =
        DialogueConstraints.from_field_snapshot(snapshot, %{
          topic_key: :tobin,
          target_name: "Tobin",
          message_intent: :ask_location
        })

      assert_constraints(constraints,
        intent: :firm_deflection,
        response_shape: :location_refusal,
        disclosure_level: :none,
        tone: [:guarded, :firm],
        allowed_facts: [],
        forbidden_topics: [
          :tobin_location,
          :tobin_private_history,
          :tobin_hidden_relationship,
          :tobin_current_activity
        ],
        field_pressure: :sensitive_location_request,
        topic_key: :tobin,
        target_name: "Tobin",
        target_public_facts: %{}
      )
    end

    test "returns normal constraints for malformed snapshots" do
      assert_constraints(
        DialogueConstraints.from_field_snapshot(%{}, %{message_intent: :ask_location}),
        normal_constraints()
      )

      assert_constraints(
        DialogueConstraints.from_field_snapshot(nil, %{message_intent: :ask_location}),
        normal_constraints()
      )
    end
  end

  describe "from_field_snapshot/1" do
    test "keeps backward-compatible default presentation behavior" do
      snapshot = mira_snapshot(pressure_count: 1)

      constraints = DialogueConstraints.from_field_snapshot(snapshot)

      assert_constraints(constraints,
        response_shape: :open_response,
        topic_key: :general,
        target_public_facts: %{}
      )
    end
  end

  defp assert_constraints(constraints, expected) do
    Enum.each(expected, fn {key, value} ->
      assert Map.fetch!(constraints, key) == value
    end)
  end

  defp mira_snapshot(opts) do
    pressure_count = Keyword.fetch!(opts, :pressure_count)

    %{
      entity_id: "npc_tobin",
      topic_salience: %{mira: :high},
      topic_pressure_counts: %{mira: pressure_count},
      disclosure_boundaries: %{mira: boundary_for(pressure_count)},
      trust_deltas: %{"player" => -pressure_count},
      private_concerns: concerns_for(:mira, pressure_count),
      presentations: []
    }
  end

  defp tobin_snapshot(opts) do
    pressure_count = Keyword.fetch!(opts, :pressure_count)

    %{
      entity_id: "npc_mira",
      topic_salience: %{tobin: :high},
      topic_pressure_counts: %{tobin: pressure_count},
      disclosure_boundaries: %{tobin: boundary_for(pressure_count)},
      trust_deltas: %{"player" => -pressure_count},
      private_concerns: concerns_for(:tobin, pressure_count),
      presentations: []
    }
  end

  defp boundary_for(pressure_count) when pressure_count >= 2, do: :very_high
  defp boundary_for(_pressure_count), do: :high

  defp concerns_for(topic_key, pressure_count) when pressure_count >= 2 do
    [
      :"player_asking_about_#{topic_key}",
      :"player_repeatedly_asking_about_#{topic_key}"
    ]
  end

  defp concerns_for(topic_key, _pressure_count) do
    [:"player_asking_about_#{topic_key}"]
  end

  defp normal_constraints do
    [
      intent: :normal_response,
      response_shape: :open_response,
      disclosure_level: :normal,
      tone: [:neutral],
      allowed_facts: [],
      forbidden_topics: [],
      field_pressure: :none,
      topic_key: :general,
      target_name: nil,
      target_public_facts: %{}
    ]
  end
end
