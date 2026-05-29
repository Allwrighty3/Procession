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
end
