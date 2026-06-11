defmodule Procession.World.PolicyContextTest do
  use ExUnit.Case, async: true

  alias Procession.World.PolicyContext

  defmodule FakeLoader do
    @behaviour PolicyContext

    def policy_context(_conn, "world_test", "scope_market", "npc_mira") do
      [
        relationships: [
          %{
            from_id: "npc_mira",
            to_id: "npc_tobin",
            relationship_type: :sibling
          }
        ],
        topic_policies: %{
          tobin: %{
            track?: true,
            base_salience: :high,
            first_boundary: :high,
            repeated_boundary: :very_high,
            trust_delta_on_press: -1
          }
        }
      ]
    end

    def policy_context(_conn, _world_id, _scope_id, _entity_id) do
      [
        relationships: [],
        topic_policies: %{}
      ]
    end
  end

  defmodule BadShapeLoader do
    @behaviour PolicyContext

    def policy_context(_conn, _world_id, _scope_id, _entity_id) do
      [
        relationships: :not_a_list,
        topic_policies: :not_a_map
      ]
    end
  end

  defmodule MissingKeysLoader do
    @behaviour PolicyContext

    def policy_context(_conn, _world_id, _scope_id, _entity_id) do
      []
    end
  end

  test "returns normalized policy context from a loader" do
    context =
      PolicyContext.for_entity(
        FakeLoader,
        :fake_conn,
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
             topic_policies: %{
               tobin: %{
                 track?: true,
                 base_salience: :high,
                 first_boundary: :high,
                 repeated_boundary: :very_high,
                 trust_delta_on_press: -1
               }
             }
           ] = context
  end

  test "returns empty context for unknown entity data" do
    context =
      PolicyContext.for_entity(
        FakeLoader,
        :fake_conn,
        "world_test",
        "scope_market",
        "npc_unknown"
      )

    assert context == [
             relationships: [],
             topic_policies: %{}
           ]
  end

  test "normalizes missing context keys" do
    context =
      PolicyContext.for_entity(
        MissingKeysLoader,
        :fake_conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    assert context == [
             relationships: [],
             topic_policies: %{}
           ]
  end

  test "normalizes invalid relationship and topic policy shapes" do
    context =
      PolicyContext.for_entity(
        BadShapeLoader,
        :fake_conn,
        "world_test",
        "scope_market",
        "npc_mira"
      )

    assert context == [
             relationships: [],
             topic_policies: %{}
           ]
  end

  test "returns empty context for invalid identifiers" do
    context =
      PolicyContext.for_entity(
        FakeLoader,
        :fake_conn,
        :not_a_world_id,
        "scope_market",
        "npc_mira"
      )

    assert context == [
             relationships: [],
             topic_policies: %{}
           ]
  end

  test "empty_context returns the default TopicPolicy-ready shape" do
    assert PolicyContext.empty_context() == [
             relationships: [],
             topic_policies: %{}
           ]
  end
end
