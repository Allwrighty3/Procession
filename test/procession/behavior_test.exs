defmodule Procession.BehaviorTest do
  use ExUnit.Case

  alias Procession.Behavior

  test "validate accepts world tick send_message behavior" do
    behavior = %{
      trigger: :world_tick,
      action: :send_message,
      to: "npc_mira",
      content: "Tobin quietly warned Mira that the mine road was watched."
    }

    assert Behavior.validate(behavior) == :ok
  end

  test "validate accepts optional send_message field" do
    behavior = %{
      trigger: :world_tick,
      action: :send_message,
      to: "npc_mira",
      type: :rumor,
      content: "The mine road was watched.",
      importance: 2,
      tags: [:mine, :road],
      metadata: %{source: :test}
    }

    assert Behavior.validate(behavior) == :ok
  end

  test "validate rejects non-map behavior metadata" do
    assert Behavior.validate(nil) == {:error, :invalid_behavior}
    assert Behavior.validate(:not_a_behavior) == {:error, :invalid_behavior}
    assert Behavior.validate(123) == {:error, :invalid_behavior}
  end

  test "validate rejects unsupported trigger" do
    behavior = %{
      trigger: :not_a_trigger,
      action: :send_message,
      to: "npc_mira",
      content: "Hello."
    }

    assert Behavior.validate(behavior) ==
             {:error, {:unsupported_behavior_trigger, :not_a_trigger}}
  end

  test "validate rejects unsupporte action" do
    behavior = %{
      trigger: :world_tick,
      action: :not_an_action,
      to: "npc_mira",
      content: "Absolutely not."
    }

    assert Behavior.validate(behavior) ==
             {:error, {:unsupported_behavior_action, :not_an_action}}
  end

  test "validate rejects send_message without target" do
    behavior = %{
      trigger: :world_tick,
      action: :send_message,
      content: "Hello."
    }

    assert Behavior.validate(behavior) == {:error, {:missing_behavior_field, :to}}
  end

  test "validate rejects send_message without content" do
    behavior = %{
      trigger: :world_tick,
      action: :send_message,
      to: "npc_mira"
    }

    assert Behavior.validate(behavior) == {:error, {:missing_behavior_field, :content}}
  end

  test "validate rejects send_message with empty target or content" do
    assert Behavior.validate(%{
             trigger: :world_tick,
             action: :send_message,
             to: "",
             content: "Hello."
           }) == {:error, {:invalid_behavior_field, :to}}

    assert Behavior.validate(%{
             trigger: :world_tick,
             action: :send_message,
             to: "npc_mira",
             content: ""
           }) == {:error, {:invalid_behavior_field, :content}}
  end
end
