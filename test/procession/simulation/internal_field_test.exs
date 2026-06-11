defmodule Procession.Simulation.InternalFieldTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.InternalField

  describe "new/1" do
    test "creates an empty internal field for an individual" do
      field = InternalField.new("npc_tobin")

      assert InternalField.snapshot(field) == %{
               entity_id: "npc_tobin",
               topic_salience: %{},
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

      assert snapshot.topic_salience[:mira] == :high
      assert snapshot.disclosure_boundaries[:mira] == :high
      assert snapshot.trust_deltas["player"] == -1
      assert snapshot.private_concerns == [:player_asking_about_mira]
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

      assert snapshot.topic_salience[:mira] == :very_high
      assert snapshot.disclosure_boundaries[:mira] == :very_high
      assert snapshot.trust_deltas["player"] == -2

      assert snapshot.private_concerns == [
               :player_asking_about_mira,
               :player_repeatedly_asking_about_mira
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

      assert snapshot.topic_salience == %{}
      assert snapshot.disclosure_boundaries == %{}
      assert snapshot.trust_deltas == %{}
      assert length(snapshot.presentations) == 1
    end
  end
end
