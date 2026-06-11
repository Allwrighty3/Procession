defmodule Procession.World.SQLiteRelationshipTopicPolicyTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.RelationshipTopicPolicy
  alias Procession.World.SQLiteStore
  alias Procession.WorldStoreFixture

  test "SQLite relationships can feed relationship-derived topic policies" do
    conn = WorldStoreFixture.open_migrated_store!()

    relationships =
      SQLiteStore.relationships_for(
        conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    policies =
      RelationshipTopicPolicy.from_relationships(
        "npc_mira",
        relationships
      )

    assert %{
             tobin: %{
               track?: true,
               sensitivity: :relationship_sensitive,
               base_salience: :high,
               first_boundary: :high,
               repeated_boundary: :very_high,
               trust_delta_on_press: -1
             }
           } = policies
  end
end
