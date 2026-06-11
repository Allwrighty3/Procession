defmodule Procession.World.PolicyContextSQLiteIntegrationTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.TopicPolicy
  alias Procession.World.ContextLoader
  alias Procession.World.PolicyContext
  alias Procession.WorldStoreFixture

  test "loads SQLite-backed policy context through the PolicyContext boundary" do
    conn = WorldStoreFixture.open_migrated_store!()

    context =
      PolicyContext.for_entity(
        ContextLoader,
        conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    policy = TopicPolicy.for_topic(:tobin, context)

    assert policy.track? == true
    assert policy.base_salience == :high
    assert policy.first_boundary == :high
    assert policy.repeated_boundary == :very_high
    assert policy.trust_delta_on_press == -1
    assert policy.first_concern == :player_asking_about_tobin
    assert policy.repeated_concern == :player_repeatedly_asking_about_tobin
  end

  test "returns empty SQLite-backed policy context for an unloaded scope" do
    conn = WorldStoreFixture.open_migrated_store!()

    context =
      PolicyContext.for_entity(
        ContextLoader,
        conn,
        "world_test",
        "scope_elsewhere",
        "npc_mira"
      )

    assert context == [
             relationships: [],
             topic_policies: %{}
           ]
  end
end
