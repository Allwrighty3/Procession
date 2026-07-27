defmodule Procession.Simulation.ResidentPersistentActionsTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LivingBriarRuntime

  test "resident gathering advances without a cognitive opportunity while in material contact" do
    {:ok, runtime} = LivingBriarRuntime.start_link(seed: 41, budget: 0, cadence: 8)

    :sys.replace_state(runtime, fn state ->
      process = %{
        primitive: :contact_loose_raw,
        action: %{primitive: :contact_loose_raw},
        region_id: :crossroads,
        started_tick: 0,
        accumulated: 0.0
      }

      crossroads = state.regions.crossroads
      mara = %{crossroads.residents["mara"] | position: {0, -2}}
      crossroads = %{crossroads | residents: Map.put(crossroads.residents, "mara", mara)}

      %{
        state
        | regions: Map.put(state.regions, :crossroads, crossroads),
          resident_processes: %{"mara" => process}
      }
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

  test "resident local movement approaches loose material across world ticks" do
    {:ok, runtime} = LivingBriarRuntime.start_link(seed: 41, budget: 0, cadence: 8)

    :sys.replace_state(runtime, fn state ->
      process = %{
        primitive: :move_local,
        action: %{primitive: :move_local, target: :loose_raw, direction: :north},
        region_id: :crossroads,
        started_tick: 0,
        accumulated: 0.0
      }

      %{state | resident_processes: %{"mara" => process}}
    end)

    assert {:ok, first} = LivingBriarRuntime.step(runtime)

    assert [%{identity: "mara", primitive: :move_local, status: :continuing, amount: 1.0}] =
             first.resident_process_events

    first_state = :sys.get_state(runtime)
    assert first_state.regions.crossroads.residents["mara"].position == {0, -1}
    assert first.decisions == []

    assert {:ok, second} = LivingBriarRuntime.step(runtime)

    assert [%{identity: "mara", primitive: :move_local, status: :ended, amount: 1.0}] =
             second.resident_process_events

    second_state = :sys.get_state(runtime)
    assert second_state.regions.crossroads.residents["mara"].position == {0, -2}
    assert second.resident_processes == %{}
    assert second.decisions == []

    summary = LivingBriarRuntime.snapshot(runtime)
    assert summary.resident_process_progress == 1
    assert summary.resident_process_endings == 1
    assert abs(summary.material_accounting_error) < 1.0e-8

    LivingBriarRuntime.stop(runtime)
  end

  test "resident contact transfer ends when the target leaves contact" do
    {:ok, runtime} = LivingBriarRuntime.start_link(seed: 41, budget: 0, cadence: 8)

    {orin_usable, lena_usable} =
      :sys.replace_state(runtime, fn state ->
        west = state.regions.west_fields
        orin = west.residents["orin"]
        lena = %{west.residents["lena"] | position: {4, 0}}
        west = %{west | residents: west.residents |> Map.put("orin", orin) |> Map.put("lena", lena)}

        process = %{
          primitive: :contact_body,
          action: %{primitive: :contact_body, counterparty_id: "lena"},
          region_id: :west_fields,
          started_tick: 0,
          accumulated: 0.0
        }

        put_in(state.regions.west_fields, west)
        |> Map.put(:resident_processes, %{"orin" => process})
      end)
      |> then(fn state ->
        west = state.regions.west_fields.residents
        {west["orin"].usable, west["lena"].usable}
      end)

    assert {:ok, observation} = LivingBriarRuntime.step(runtime)

    assert [
             %{
               identity: "orin",
               primitive: :contact_body,
               status: :ended,
               consequence: :body_out_of_contact,
               amount: 0.0
             }
           ] = observation.resident_process_events

    state = :sys.get_state(runtime)
    assert state.regions.west_fields.residents["orin"].usable == orin_usable
    assert state.regions.west_fields.residents["lena"].usable == lena_usable
    assert observation.resident_processes == %{}

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

    assert [
             %{
               identity: "mara",
               status: :ended,
               consequence: :transformed_material,
               amount: amount
             }
           ] = observation.resident_process_events

    assert amount > 0.0
    assert observation.resident_processes == %{}

    summary = LivingBriarRuntime.snapshot(runtime)
    assert summary.resident_process_endings == 1
    assert abs(summary.material_accounting_error) < 1.0e-8

    LivingBriarRuntime.stop(runtime)
  end
end
