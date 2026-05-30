defmodule Procession.BehaviorTest do
  use ExUnit.Case

  alias Procession.Behavior

  describe "validate/1" do
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

    test "validate accepts change_status behavior" do
      behavior = %{
        trigger: :world_tick,
        action: :change_status,
        status: :alert
      }

      assert Behavior.validate(behavior) == :ok
    end

    test "validate rejects change_status without status" do
      behavior = %{
        trigger: :world_tick,
        action: :change_status
      }

      assert Behavior.validate(behavior) == {:error, {:missing_behavior_field, :status}}
    end

    test "validate rejects change_status with invalid status" do
      behavior = %{
        trigger: :world_tick,
        action: :change_status,
        status: "alert"
      }

      assert Behavior.validate(behavior) == {:error, {:invalid_behavior_field, :status}}
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

  describe "execute/2" do
    test "execute performs send_message behavior" do
      {:ok, _sender} =
        Procession.EntitySupervisor.start_npc("npc_sender_behavior_test", %{
          name: "Sender",
          location: "loc_test"
        })

      {:ok, _receiver} =
        Procession.EntitySupervisor.start_npc("npc_receiver_behavior_test", %{
          name: "Receiver",
          location: "loc_test"
        })

      sender_state = Procession.Entity.get_state("npc_sender_behavior_test")

      behavior = %{
        trigger: :world_tick,
        action: :send_message,
        to: "npc_receiver_behavior_test",
        type: :rumor,
        content: "The mine road was watched.",
        importance: 2,
        tags: [:mine]
      }

      assert Procession.Behavior.execute(sender_state, behavior) ==
               {%{
                  status: :ok,
                  action: :send_message,
                  from: "npc_sender_behavior_test",
                  to: "npc_receiver_behavior_test",
                  type: :rumor,
                  content: "The mine road was watched."
                }, sender_state}

      Process.sleep(10)

      memories = Procession.Entity.recall_all("npc_receiver_behavior_test")

      assert Enum.any?(memories, fn memory ->
               memory.from == "npc_sender_behavior_test" and
                 memory.content == "The mine road was watched." and
                 memory.metadata.source == :entity_tick
             end)

      Procession.EntitySupervisor.stop_entity("npc_sender_behavior_test")
      Procession.EntitySupervisor.stop_entity("npc_receiver_behavior_test")
    end

    test "execute changes entity status" do
      entity_state = %{
        id: "npc_status_behavior_test",
        status: :idle
      }

      behavior = %{
        trigger: :world_tick,
        action: :change_status,
        status: :alert
      }

      assert Procession.Behavior.execute(entity_state, behavior) ==
               {%{
                  status: :ok,
                  action: :change_status,
                  entity_id: "npc_status_behavior_test",
                  old_status: :idle,
                  new_status: :alert
                }, %{entity_state | status: :alert}}
    end

    test "execute returns validation errors for invalid behavior" do
      entity_state = %{id: "npc_sender_behavior_test"}

      behavior = %{
        trigger: :world_tick,
        action: :not_an_action,
        to: "npc_receiver_behavior_test",
        content: "Nope."
      }

      assert Procession.Behavior.execute(entity_state, behavior) ==
               {%{
                  status: :error,
                  action: :not_an_action,
                  from: "npc_sender_behavior_test",
                  reason: {:unsupported_behavior_action, :not_an_action}
                }, entity_state}
    end
  end
end
