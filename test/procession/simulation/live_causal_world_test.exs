defmodule Procession.Simulation.LiveCausalWorldTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LiveCausalWorld

  setup do
    if pid = Process.whereis(LiveCausalWorld) do
      GenServer.stop(pid)
    end

    :ok
  end

  test "live world persists authoritative state across ticks" do
    start_supervised!({LiveCausalWorld,
      kernel_opts: [
        bounds: {4, 4},
        obstacles: [{1, 0}, {1, 2}, {0, 1}, {2, 1}],
        entities: [
          %{
            id: "mara",
            position: {1, 1},
            loop_opts: [
              field_opts: [micro_nodes: 64, input_width: 3, encoding_salt: :live_world_test],
              body_opts: [initial_coordination: 1.0]
            ]
          }
        ],
        resources: [%{id: "food", position: {1, 1}, quantity: 0.4}]
      ]})

    assert {:ok, first} = LiveCausalWorld.tick()
    assert first.tick == 1
    assert first.entities["mara"].sensorimotor.cycles == 1

    assert {:ok, second} = LiveCausalWorld.tick()
    assert second.tick == 2
    assert second.entities["mara"].sensorimotor.cycles == 2
    assert second.resources["food"] < first.resources["food"]
  end

  test "world clock advances a running causal world without requiring named entity actions" do
    start_supervised!({LiveCausalWorld,
      kernel_opts: [
        entities: [
          %{
            id: "clock_entity",
            position: {0, 0},
            loop_opts: [
              field_opts: [micro_nodes: 64, input_width: 3, encoding_salt: :clock_world_test],
              body_opts: [initial_coordination: 1.0]
            ]
          }
        ]
      ]})

    clock = start_supervised!({Procession.WorldClock, name: :causal_world_test_clock})

    assert {:ok, summary} = Procession.WorldClock.tick(clock)
    assert summary.clock_tick == 1
    assert summary.causal_world.tick == 1
    assert summary.causal_world.entities["clock_entity"].sensorimotor.cycles == 1
  end

  test "world clock reports a clean skip when no causal world is active" do
    clock = start_supervised!({Procession.WorldClock, name: :empty_causal_world_test_clock})

    assert {:ok, summary} = Procession.WorldClock.tick(clock)
    assert summary.causal_world == %{status: :skipped, reason: :causal_world_not_running}
  end
end
