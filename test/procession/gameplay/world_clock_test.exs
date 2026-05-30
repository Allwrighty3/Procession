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
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    assert Procession.WorldClock.last_tick(clock) == nil
    assert Procession.WorldClock.tick_count(clock) == 0
  end

  test "manually coordinates one world tick" do
    assert {:ok, _game} = Procession.Game.new_game("anything")
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    assert {:ok, summary} = Procession.WorldClock.tick(clock)

    assert summary.clock_tick == 1
    assert summary.entities_ticked >= 1
    assert is_list(summary.actions)
    assert is_list(summary.successful_actions)
    assert is_list(summary.failed_actions)

    assert Procession.WorldClock.tick_count(clock) == 1
    assert Procession.WorldClock.last_tick(clock) == summary
  end

  test "manual clock ticks preserve Game.tick_all_live_entities behavior" do
    assert {:ok, _game} = Procession.Game.new_game("anything")
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    assert {:ok, summary} = Procession.WorldClock.tick(clock)

    assert Enum.any?(summary.actions, fn action ->
             action.action == :send_message or action.action == :change_status
           end)
  end

  test "multiple manual ticks increment the clock count" do
    assert {:ok, _game} = Procession.Game.new_game("anything")
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

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

    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

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

    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

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

  test "supervised clock is available by default" do
    assert Process.whereis(Procession.WorldClock)
    assert is_integer(Procession.WorldClock.tick_count())
  end

  test "supervised clock restarts with fresh state if it crashes" do
    original_pid = Process.whereis(Procession.WorldClock)
    assert is_pid(original_pid)

    Process.exit(original_pid, :kill)

    restarted_pid =
      Enum.find_value(1..20, fn _attempt ->
        Process.sleep(10)

        case Process.whereis(Procession.WorldClock) do
          pid when is_pid(pid) and pid != original_pid -> pid
          _ -> nil
        end
      end)

    assert is_pid(restarted_pid)
    assert Process.alive?(restarted_pid)

    assert Procession.WorldClock.tick_count() == 0
    assert Procession.WorldClock.last_tick() == nil
  end

  test "default clock API uses the supervised clock" do
    assert {:ok, _game} = Procession.Game.new_game("anything")

    initial_count = Procession.WorldClock.tick_count()

    assert {:ok, summary} = Procession.WorldClock.tick()

    assert summary.clock_tick == initial_count + 1
    assert Procession.WorldClock.tick_count() == initial_count + 1
    assert Procession.WorldClock.last_tick() == summary
  end

  test "interval ticking is disabled by default" do
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    refute Procession.WorldClock.interval_running?(clock)
    assert Procession.WorldClock.tick_count(clock) == 0

    Process.sleep(30)

    assert Procession.WorldClock.tick_count(clock) == 0
  end

  test "can start and stop interval ticking" do
    assert {:ok, _game} = Procession.Game.new_game("anything")
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    assert :ok = Procession.WorldClock.start_interval(clock, 10)
    assert Procession.WorldClock.interval_running?(clock)

    Process.sleep(35)

    assert Procession.WorldClock.tick_count(clock) >= 1

    assert :ok = Procession.WorldClock.stop_interval(clock)
    refute Procession.WorldClock.interval_running?(clock)

    tick_count_after_stop = Procession.WorldClock.tick_count(clock)

    Process.sleep(30)

    assert Procession.WorldClock.tick_count(clock) == tick_count_after_stop
  end

  test "starting interval ticking replaces the previous interval" do
    assert {:ok, _game} = Procession.Game.new_game("anything")
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    assert :ok = Procession.WorldClock.start_interval(clock, 50)
    assert Procession.WorldClock.interval_running?(clock)

    assert :ok = Procession.WorldClock.start_interval(clock, 10)
    assert Procession.WorldClock.interval_running?(clock)

    Process.sleep(35)

    assert Procession.WorldClock.tick_count(clock) >= 1

    assert :ok = Procession.WorldClock.stop_interval(clock)
  end
end
