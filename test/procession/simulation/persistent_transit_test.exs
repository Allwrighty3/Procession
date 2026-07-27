defmodule Procession.Simulation.PersistentTransitTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LivingBriarRuntime

  test "boundary crossing leaves regional contact and arrives after route progress" do
    {:ok, runtime} = LivingBriarRuntime.start_link(seed: 41, budget: 0, cadence: 8)

    :sys.replace_state(runtime, fn state ->
      process = %{
        primitive: :cross_region_boundary,
        action: %{primitive: :cross_region_boundary, direction: :east, region_id: :east_refuge},
        region_id: :crossroads,
        started_tick: 0,
        accumulated: 0.0
      }

      %{state | resident_processes: %{"mara" => process}}
    end)

    assert LivingBriarRuntime.snapshot(runtime).populations.crossroads == 1

    assert {:ok, first} = LivingBriarRuntime.step(runtime)
    assert first.populations.crossroads == 0
    assert first.populations.east_refuge == 2
    assert first.resident_processes["mara"].accumulated == 1.0
    assert [%{identity: "mara", status: :continuing}] = first.resident_process_events

    assert {:ok, _} = LivingBriarRuntime.step(runtime)
    assert {:ok, _} = LivingBriarRuntime.step(runtime)
    assert {:ok, arrival} = LivingBriarRuntime.step(runtime)

    assert arrival.populations.crossroads == 0
    assert arrival.populations.east_refuge == 3
    assert arrival.resident_processes == %{}

    assert [%{identity: "mara", status: :arrived, consequence: :crossed_region_boundary}] =
             arrival.resident_process_events

    summary = LivingBriarRuntime.snapshot(runtime)
    assert summary.transit_starts == 0
    assert summary.transit_progress == 3
    assert summary.transit_arrivals == 1
    assert summary.migrations == 1
    assert abs(summary.material_accounting_error) < 1.0e-8

    LivingBriarRuntime.stop(runtime)
  end

  test "transit body remains conserved while outside every region" do
    {:ok, runtime} = LivingBriarRuntime.start_link(seed: 41, budget: 0, cadence: 8)

    :sys.replace_state(runtime, fn state ->
      process = %{
        primitive: :cross_region_boundary,
        action: %{primitive: :cross_region_boundary, direction: :west, region_id: :west_fields},
        region_id: :crossroads,
        started_tick: 0,
        accumulated: 0.0
      }

      %{state | resident_processes: %{"mara" => process}}
    end)

    assert {:ok, observation} = LivingBriarRuntime.step(runtime)
    refute Map.has_key?(observation.populations, :transit)
    assert observation.populations.crossroads == 0

    summary = LivingBriarRuntime.snapshot(runtime)
    assert summary.resident_processes["mara"].body.id == "mara"
    assert abs(summary.material_accounting_error) < 1.0e-8

    LivingBriarRuntime.stop(runtime)
  end
end
