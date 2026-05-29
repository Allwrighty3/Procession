defmodule Procession.WorldClockTest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)

    :ok
  end

  test "starts with no last tick and zero tick count" do
    assert {:ok, clock} = Procession.WorldClock.start_link([])

    assert Procession.WorldClock.last_tick(clock) == nil
    assert Procession.WorldClock.tick_count(clock) == 0
  end

  test "manually coordinates one world tick" do
    assert {:ok, _game} = Procession.Game.new_game("anything")
    assert {:ok, clock} = Procession.WorldClock.start_link([])

    assert {:ok, summary} = Procession.WorldClock.tick(clock)

    assert summary.clock_tick == 1
    assert summary.entities_ticked >= 1
    assert is_list(summary.actions)
    assert is_list(summary.successful_actions)
    assert is_list(summary.failed_actions)

    assert Procession.WorldClock.tick_count(clock) == 1
    assert Procession.WorldClock.last_tick(clock) == summary
  end

  test "manual clock ticks preserve Game.tick_world behavior" do
    assert {:ok, _game} = Procession.Game.new_game("anything")
    assert {:ok, clock} = Procession.WorldClock.start_link([])

    assert {:ok, summary} = Procession.WorldClock.tick(clock)

    assert Enum.any?(summary.actions, fn action ->
             action.action == :send_message or action.action == :change_status
           end)
  end

  test "multiple manual ticks increment the clock count" do
    assert {:ok, _game} = Procession.Game.new_game("anything")
    assert {:ok, clock} = Procession.WorldClock.start_link([])

    assert {:ok, first_summary} = Procession.WorldClock.tick(clock)
    assert {:ok, second_summary} = Procession.WorldClock.tick(clock)

    assert first_summary.clock_tick == 1
    assert second_summary.clock_tick == 2
    assert Procession.WorldClock.tick_count(clock) == 2
    assert Procession.WorldClock.last_tick(clock) == second_summary
  end

  test "clock remains alive after a failed behavior action" do
    assert {:ok, _pid} =
             Procession.EntitySupervisor.start_npc("npc_faulty", %{
               name: "Faulty",
               location: "loc_nowhere",
               metadata: %{
                 behaviors: [
                   %{
                     trigger: :world_tick,
                     action: :send_message,
                     to: "npc_missing",
                     content: "This message has nowhere to go."
                   }
                 ]
               }
             })

    assert {:ok, clock} = Procession.WorldClock.start_link([])

    assert {:ok, summary} = Procession.WorldClock.tick(clock)

    assert summary.clock_tick == 1
    assert Procession.WorldClock.tick_count(clock) == 1
    assert Process.alive?(clock)

    assert Enum.any?(summary.failed_actions, fn action ->
             action.status == :error and
               action.action == :send_message and
               action.from == "npc_faulty" and
               action.to == "npc_missing" and
               action.reason == :entity_not_found
           end)

    assert Procession.WorldClock.last_tick(clock) == summary
  end

  test "clock remains alive after unsupported behavior metadata" do
    assert {:ok, _pid} =
             Procession.EntitySupervisor.start_npc("npc_confused", %{
               name: "Confused",
               location: "loc_nowhere",
               metadata: %{
                 behaviors: [
                   %{
                     trigger: :world_tick,
                     action: :teleport_to_moon
                   }
                 ]
               }
             })

    assert {:ok, clock} = Procession.WorldClock.start_link([])

    assert {:ok, summary} = Procession.WorldClock.tick(clock)

    assert summary.clock_tick == 1
    assert Process.alive?(clock)
    assert Procession.WorldClock.tick_count(clock) == 1

    assert Enum.any?(summary.failed_actions, fn action ->
             action.status == :error and
               action.action == :teleport_to_moon and
               action.from == "npc_confused" and
               action.reason == {:unsupported_behavior_action, :teleport_to_moon}
           end)

    assert Procession.WorldClock.last_tick(clock) == summary
  end
end
