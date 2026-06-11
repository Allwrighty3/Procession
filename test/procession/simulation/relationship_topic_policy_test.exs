defmodule Procession.Simulation.RelationshipTopicPolicyTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.RelationshipTopicPolicy

  describe "from_relationships/2" do
    test "derives topic policies for relationships owned by the entity" do
      relationships = [
        %{
          source_id: "npc_tobin",
          target_id: "npc_mira",
          sensitivity: :relationship_sensitive
        }
      ]

      assert RelationshipTopicPolicy.from_relationships("npc_tobin", relationships) == %{
               mira: %{
                 track?: true,
                 sensitivity: :relationship_sensitive,
                 base_salience: :high,
                 first_boundary: :high,
                 repeated_boundary: :very_high,
                 trust_delta_on_press: -1
               }
             }
    end

    test "uses explicit target topic key when present" do
      relationships = [
        %{
          source_id: "npc_mira",
          target_id: "npc_tobin",
          target_topic_key: :tobin,
          sensitivity: :protective,
          first_boundary: :medium,
          repeated_boundary: :high,
          trust_delta_on_press: -2
        }
      ]

      assert RelationshipTopicPolicy.from_relationships("npc_mira", relationships) == %{
               tobin: %{
                 track?: true,
                 sensitivity: :protective,
                 base_salience: :high,
                 first_boundary: :medium,
                 repeated_boundary: :high,
                 trust_delta_on_press: -2
               }
             }
    end

    test "uses disclosure boundary as first boundary when provided" do
      relationships = [
        %{
          entity_id: "npc_tobin",
          target_id: "npc_mira",
          disclosure_boundary: :very_high
        }
      ]

      assert RelationshipTopicPolicy.from_relationships("npc_tobin", relationships).mira.first_boundary ==
               :very_high
    end

    test "ignores relationships for other entities" do
      relationships = [
        %{
          source_id: "npc_elin",
          target_id: "npc_mira"
        }
      ]

      assert RelationshipTopicPolicy.from_relationships("npc_tobin", relationships) == %{}
    end

    test "ignores malformed relationships" do
      relationships = [
        %{source_id: "npc_tobin"},
        :not_a_relationship,
        nil
      ]

      assert RelationshipTopicPolicy.from_relationships("npc_tobin", relationships) == %{}
    end

    test "derives topic policies from generator-style from/to relationships" do
      relationships = [
        %{
          from: "npc_mira",
          to: "npc_tobin",
          type: :distrusts,
          description: "Mira thinks Tobin knows more about the mine than he admits."
        }
      ]

      assert RelationshipTopicPolicy.from_relationships("npc_mira", relationships) == %{
              tobin: %{
                track?: true,
                sensitivity: :relationship_sensitive,
                base_salience: :high,
                first_boundary: :high,
                repeated_boundary: :very_high,
                trust_delta_on_press: -1
              }
            }
    end
  end
end
