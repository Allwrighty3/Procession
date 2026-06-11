defmodule Procession.World.SQLiteStoreTest do
  use ExUnit.Case, async: false

  alias Procession.World.SQLiteStore
  alias Procession.WorldStoreFixture

  test "loads scoped relationships for an entity" do
    conn = WorldStoreFixture.open_migrated_store!()

    relationships =
      SQLiteStore.relationships_for(
        conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    assert [
             %{
               from_id: "npc_mira",
               to_id: "npc_tobin",
               relationship_type: :sibling,
               target_topic_key: :tobin,
               sensitivity: :relationship_sensitive,
               base_salience: :high,
               first_boundary: :high,
               repeated_boundary: :very_high,
               trust_delta_on_press: -1
             }
           ] = relationships
  end

  test "loads scoped relationships between two entities" do
    conn = WorldStoreFixture.open_migrated_store!()

    relationships =
      SQLiteStore.relationships_between(
        conn,
        "world_test",
        "scope_market",
        "npc_mira",
        "npc_tobin"
      )

    assert length(relationships) == 1
    assert hd(relationships).relationship_type == :sibling
  end

  test "does not load relationships from another scope" do
    conn = WorldStoreFixture.open_migrated_store!()

    relationships =
      SQLiteStore.relationships_for(
        conn,
        "world_test",
        "scope_elsewhere",
        "npc_mira"
      )

    assert relationships == []
  end

  test "loads topic policies as TopicPolicy-compatible context data" do
    conn = WorldStoreFixture.open_migrated_store!()

    policies =
      SQLiteStore.topic_policies_for(
        conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    assert %{
             tobin: %{
               track?: true,
               base_salience: :high,
               first_boundary: :high,
               repeated_boundary: :very_high,
               trust_delta_on_press: -1,
               first_concern: :player_asking_about_tobin,
               repeated_concern: :player_repeatedly_asking_about_tobin
             }
           } = policies
  end
end
