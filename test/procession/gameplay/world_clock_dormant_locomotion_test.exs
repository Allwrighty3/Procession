defmodule Procession.WorldClockDormantLocomotionTest do
  use ExUnit.Case, async: true

  defmodule FakeDormantBatch do
    def run(tick, provider, opts) do
      recipient = Keyword.fetch!(opts, :recipient)
      travel_server = Keyword.fetch!(opts, :travel_server)
      exits = provider.("traveler", "region_a")
      send(recipient, {:dormant_batch, tick, exits, travel_server, opts})

      %{
        tick: tick,
        waiting: 3,
        attempted: Keyword.get(opts, :budget, 0),
        succeeded: Keyword.get(opts, :budget, 0),
        failed: 0,
        deferred: max(0, 3 - Keyword.get(opts, :budget, 0))
      }
    end
  end

  test "dormant locomotion remains disabled by default" do
    assert {:ok, clock} = Procession.WorldClock.start_link(name: nil)
    assert {:ok, summary} = Procession.WorldClock.tick(clock)
    assert summary.dormant_locomotion == :disabled
  end

  test "runs a bounded dormant batch only on its configured cadence" do
    provider = fn identity_id, region_id ->
      [%{identity_id: identity_id, region_id: region_id, direction: :north}]
    end

    assert {:ok, clock} =
             Procession.WorldClock.start_link(
               name: nil,
               dormant_locomotion: true,
               dormant_locomotion_module: FakeDormantBatch,
               dormant_locomotion_cadence: 2,
               dormant_exit_provider: provider,
               coarse_travel_server: :coarse_travel_for_test,
               dormant_locomotion_opts: [recipient: self(), budget: 2]
             )

    assert {:ok, first} = Procession.WorldClock.tick(clock)
    assert first.dormant_locomotion == %{status: :deferred, cadence: 2, next_eligible_tick: 2}
    refute_receive {:dormant_batch, _, _, _, _}

    assert {:ok, second} = Procession.WorldClock.tick(clock)

    assert second.dormant_locomotion == %{
             tick: 2,
             waiting: 3,
             attempted: 2,
             succeeded: 2,
             failed: 0,
             deferred: 1
           }

    assert_receive {:dormant_batch, 2,
                    [%{identity_id: "traveler", region_id: "region_a", direction: :north}],
                    :coarse_travel_for_test, opts}

    assert Keyword.fetch!(opts, :budget) == 2
  end

  test "reports configuration failure without crashing the clock" do
    assert {:ok, clock} =
             Procession.WorldClock.start_link(
               name: nil,
               dormant_locomotion: true,
               dormant_locomotion_module: FakeDormantBatch,
               dormant_locomotion_cadence: 1,
               dormant_locomotion_opts: [recipient: self(), budget: 1]
             )

    assert {:ok, summary} = Procession.WorldClock.tick(clock)
    assert summary.dormant_locomotion == %{status: :error, reason: :dormant_exit_provider_required}
    assert Process.alive?(clock)
  end

  test "normalizes an invalid cadence to one tick" do
    provider = fn _identity_id, _region_id -> [] end

    assert {:ok, clock} =
             Procession.WorldClock.start_link(
               name: nil,
               dormant_locomotion: true,
               dormant_locomotion_module: FakeDormantBatch,
               dormant_locomotion_cadence: 0,
               dormant_exit_provider: provider,
               dormant_locomotion_opts: [recipient: self(), budget: 1]
             )

    assert {:ok, summary} = Procession.WorldClock.tick(clock)
    assert summary.dormant_locomotion.tick == 1
    assert_receive {:dormant_batch, 1, [], _, _}
  end
end
