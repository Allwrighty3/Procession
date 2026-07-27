defmodule Procession.Simulation.ResidentPersistentActionsTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LivingBriarRuntime

  test "resident gathering advances without a cognitive opportunity" do
    {:ok, runtime} = LivingBriarRuntime.start_link(seed: 41, budget: 0, cadence: 8)

    :sys.replace_state(runtime, fn state ->
      process = %{
        primitive: :contact_loose_raw,
        action: %{primitive: :contact_loose_raw},
        region_id: :crossroads,
        started_tick: 0,
        accumulated: 0.0
      }

      %{state | resident_processes: %{"mara" => process}}
    end)

    before = LivingBriarRuntime.snapshot(runtime)
    assert before.decisions == 0

    assert {:ok, first} = LivingBriarRuntime.step(runtime)
    assert first.decisions == []
    assert first.deferred == 6

    assert [%{identity: "mara", status: :continuing, amount: first_amount}] =
             first.resident_process_events

    assert first_amount > 0.0
    assert first.resident_processes["mara"].accumulated == first_amount

    assert {:ok, second} = LivingBriarRuntime.step(runtime)
    assert second.decisions == []

    assert [%{identity: "mara", status: :continuing, amount: second_amount}] =
             second.resident_process_events

    assert second_amount > 0.0
    assert second.resident_processes["mara"].accumulated == first_amount + second_amount

    summary = LivingBriarRuntime.snapshot(runtime)
    assert summary.decisions == 0
    assert summary.resident_process_progress == 2
    assert abs(summary.material_accounting_error) < 1.0e-8

    LivingBriarRuntime.stop(runtime)
  end

  test "resident transformation ends when held raw is exhausted" do
    {:ok, runtime} = LivingBriarRuntime.start_link(seed: 41, budget: 0, cadence: 8)

    :sys.replace_state(runtime, fn state ->
      process = %{
        primitive: :manipulate_held_raw,
        action: %{primitive: :manipulate_held_raw},
        region_id: :crossroads,
        started_tick: 0,
        accumulated: 0.0
      }

      %{state | resident_processes: %{"mara" => process}}
    end)

    assert {:ok, observation} = LivingBriarRuntime.step(runtime)

    assert [%{identity: "mara", status: :ended, consequence: :transformed_material, amount: amount}] =
             observation.resident_process_events

    assert amount > 0.0
    assert observation.resident_processes == %{}

    summary = LivingBriarRuntime.snapshot(runtime)
    assert summary.resident_process_endings == 1
    assert abs(summary.material_accounting_error) < 1.0e-8

    LivingBriarRuntime.stop(runtime)
  end
end
