defmodule Procession.WorldClockTemporalTest do
  use ExUnit.Case, async: true

  test "world time is monotonic and advances independently of wall time" do
    assert {:ok, clock} =
             Procession.WorldClock.start_link(
               name: nil,
               initial_time_ms: 5_000,
               tick_duration_ms: 250
             )

    assert Procession.WorldClock.now(clock) == 5_000
    assert {:ok, []} = Procession.WorldClock.advance_to(clock, 5_125)
    assert Procession.WorldClock.now(clock) == 5_125

    assert {:error, :world_time_cannot_move_backward} =
             Procession.WorldClock.advance_to(clock, 5_124)

    assert Procession.WorldClock.now(clock) == 5_125
  end

  test "actions occupy time and complete only at their temporal boundary" do
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    assert {:ok, process} =
             Procession.WorldClock.start_process(clock, %{
               id: "walk-to-well",
               kind: :walk,
               subject_id: "npc_elin",
               duration_ms: 12_000,
               effect: %{type: :arrive, location: "loc_well"}
             })

    assert process.started_at == 0
    assert process.next_transition_at == 12_000
    assert Procession.WorldClock.active_processes(clock) == [process]

    assert {:ok, []} = Procession.WorldClock.advance_to(clock, 11_999)
    assert Procession.WorldClock.active_processes(clock) == [process]

    assert {:ok, [completed]} = Procession.WorldClock.advance_to(clock, 12_000)
    assert completed.id == "walk-to-well"
    assert completed.state == :completed
    assert Procession.WorldClock.active_processes(clock) == []
  end

  test "advance_to_next jumps directly to the next meaningful boundary" do
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    assert {:ok, _later} =
             Procession.WorldClock.start_process(clock, %{
               id: "later",
               kind: :hunger_threshold,
               subject_id: "npc_elin",
               duration_ms: 5_000
             })

    assert {:ok, _sooner} =
             Procession.WorldClock.start_process(clock, %{
               id: "sooner",
               kind: :finish_speaking,
               subject_id: "npc_tobin",
               duration_ms: 800
             })

    assert {:ok, [completed]} = Procession.WorldClock.advance_to_next(clock)
    assert completed.id == "sooner"
    assert Procession.WorldClock.now(clock) == 800
    assert Enum.map(Procession.WorldClock.active_processes(clock), & &1.id) == ["later"]
  end

  test "multiple compatible processes coexist without a single action slot" do
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    for {id, kind, duration} <- [
          {"walking", :walk, 2_000},
          {"listening", :listen, 500},
          {"digesting", :digest, 4_000},
          {"thinking", :deliberation, 120}
        ] do
      assert {:ok, _process} =
               Procession.WorldClock.start_process(clock, %{
                 id: id,
                 kind: kind,
                 subject_id: "npc_elin",
                 duration_ms: duration
               })
    end

    assert Enum.map(Procession.WorldClock.active_processes(clock), & &1.id) == [
             "thinking",
             "listening",
             "walking",
             "digesting"
           ]
  end

  test "ticks advance configured simulation time and report completed processes" do
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil, tick_duration_ms: 1_000)

    assert {:ok, _process} =
             Procession.WorldClock.start_process(clock, %{
               id: "brief-thought",
               kind: :deliberation,
               subject_id: "npc_elin",
               duration_ms: 120
             })

    assert {:ok, summary} = Procession.WorldClock.tick(clock)
    assert summary.world_time_ms == 1_000
    assert Enum.map(summary.completed_processes, & &1.id) == ["brief-thought"]
  end

  test "a process can be cancelled before completion" do
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)

    assert {:ok, _process} =
             Procession.WorldClock.start_process(clock, %{
               id: "interrupted-walk",
               kind: :walk,
               subject_id: "npc_elin",
               duration_ms: 2_000
             })

    assert {:ok, cancelled} =
             Procession.WorldClock.cancel_process(clock, "interrupted-walk")

    assert cancelled.state == :cancelled
    assert {:ok, []} = Procession.WorldClock.advance_to(clock, 2_000)
  end
end
