defmodule Procession.World.ContextLoaderTest do
  use ExUnit.Case, async: false

  alias Procession.World.ContextLoader
  alias Procession.World.SQLiteStore
  alias Procession.WorldStoreFixture

  test "loads scoped relationships into policy context" do
    conn = WorldStoreFixture.open_migrated_store!()

    context =
      ContextLoader.policy_context(
        conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    assert [
             relationships: [
               %{
                 from_id: "npc_mira",
                 to_id: "npc_tobin",
                 relationship_type: :sibling
               }
             ],
             topic_policies: _topic_policies
           ] = context
  end

  test "derives topic policies from scoped relationships" do
    conn = WorldStoreFixture.open_migrated_store!()

    context =
      ContextLoader.policy_context(
        conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    topic_policies = Keyword.fetch!(context, :topic_policies)

    assert %{
             tobin: %{
               track?: true,
               sensitivity: :relationship_sensitive,
               base_salience: :high,
               first_boundary: :high,
               repeated_boundary: :very_high,
               trust_delta_on_press: -1
             }
           } = topic_policies
  end

  test "stored topic policies merge over relationship-derived policies" do
    conn = WorldStoreFixture.open_migrated_store!()

    context =
      ContextLoader.policy_context(
        conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    topic_policies = Keyword.fetch!(context, :topic_policies)

    assert topic_policies.tobin.first_concern == :player_asking_about_tobin
    assert topic_policies.tobin.repeated_concern == :player_repeatedly_asking_about_tobin

    assert topic_policies.tobin.sensitivity == :relationship_sensitive
  end

  test "does not load relationships or topic policies from another scope" do
    conn = WorldStoreFixture.open_migrated_store!()

    context =
      ContextLoader.policy_context(
        conn,
        "world_test",
        "scope_elsewhere",
        "npc_mira"
      )

    assert Keyword.fetch!(context, :relationships) == []
    assert Keyword.fetch!(context, :topic_policies) == %{}
  end

  test "does not load relationships or topic policies for another entity" do
    conn = WorldStoreFixture.open_migrated_store!()

    context =
      ContextLoader.policy_context(
        conn,
        "world_test",
        "scope_market",
        "npc_tobin"
      )

    assert Keyword.fetch!(context, :relationships) == []
    assert Keyword.fetch!(context, :topic_policies) == %{}
  end

  test "context can be consumed by TopicPolicy through topic_policies keyword data" do
    conn = WorldStoreFixture.open_migrated_store!()

    context =
      ContextLoader.policy_context(
        conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    policy =
      Procession.Simulation.TopicPolicy.for_topic(
        :tobin,
        context
      )

    assert policy.track? == true
    assert policy.base_salience == :high
    assert policy.first_boundary == :high
    assert policy.repeated_boundary == :very_high
    assert policy.trust_delta_on_press == -1
    assert policy.first_concern == :player_asking_about_tobin
    assert policy.repeated_concern == :player_repeatedly_asking_about_tobin
  end
end
