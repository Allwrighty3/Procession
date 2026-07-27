defmodule Procession.Simulation.InTransitCognitionTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.CognitiveMaterialKernel
  alias Procession.Simulation.TransitAwareLivingBriarRuntime

  test "a body outside every region emits and commits an opaque motor impulse" do
    {:ok, runtime} =
      TransitAwareLivingBriarRuntime.start_link(
        seed: 41,
        budget: 0,
        cadence: 8,
        transit_budget: 1,
        transit_cadence: 1
      )

    inner = :sys.get_state(runtime).runtime

    :sys.replace_state(inner, fn state ->
      {body, crossroads} =
        CognitiveMaterialKernel.remove_resident(state.regions.crossroads, "mara")

      process = %{
        primitive: :cross_region_boundary,
        action: %{primitive: :cross_region_boundary, direction: :east, region_id: :east_refuge},
        region_id: :crossroads,
        started_tick: 0,
        accumulated: 1.0,
        extent: 4.0,
        body: body,
        route_velocity: 0.0,
        lateral_velocity: 0.0,
        lateral_position: 0.0
      }

      %{
        state
        | regions: Map.put(state.regions, :crossroads, crossroads),
          resident_processes: %{"mara" => process}
      }
    end)

    assert {:ok, observation} = TransitAwareLivingBriarRuntime.step(runtime)
    assert observation.populations.crossroads == 0
    assert observation.in_transit_decisions == 1

    assert [%{identity: "mara", in_transit?: true, mind_committed?: true} = decision] =
             Enum.filter(observation.decisions, &Map.get(&1, :in_transit?, false))

    assert decision.primitive == :motor_impulse
    assert is_tuple(decision.motor_force)
    assert is_number(decision.route_projection)
    assert is_number(decision.lateral_projection)

    summary = TransitAwareLivingBriarRuntime.snapshot(runtime)
    assert summary.in_transit_decisions == 1
    assert summary.transit_motor_impulses == 1
    assert summary.transit_cognitive_primitives == %{motor_impulse: 1}
    assert summary.transit_minds_committed?
    assert map_size(summary.resident_processes) == 1
    assert abs(summary.material_accounting_error) < 1.0e-8

    TransitAwareLivingBriarRuntime.stop(runtime)
  end

  test "negative route velocity returns a traveler to the source boundary" do
    {:ok, runtime} =
      TransitAwareLivingBriarRuntime.start_link(
        seed: 41,
        budget: 0,
        cadence: 8,
        transit_budget: 0
      )

    inner = :sys.get_state(runtime).runtime

    :sys.replace_state(inner, fn state ->
      {body, crossroads} =
        CognitiveMaterialKernel.remove_resident(state.regions.crossroads, "mara")

      process = %{
        primitive: :cross_region_boundary,
        action: %{primitive: :cross_region_boundary, direction: :east, region_id: :east_refuge},
        region_id: :crossroads,
        started_tick: 0,
        accumulated: 0.5,
        extent: 4.0,
        body: body,
        route_velocity: -1.0,
        lateral_velocity: 0.0,
        lateral_position: 0.0
      }

      %{
        state
        | regions: Map.put(state.regions, :crossroads, crossroads),
          resident_processes: %{"mara" => process}
      }
    end)

    assert {:ok, observation} = TransitAwareLivingBriarRuntime.step(runtime)
    assert observation.populations.crossroads == 1
    assert observation.populations.east_refuge == 2
    assert observation.resident_processes == %{}

    assert Enum.any?(observation.resident_process_events, fn event ->
             event.identity == "mara" and event.status == :returned and
               event.consequence == :returned_to_source_boundary
           end)

    summary = TransitAwareLivingBriarRuntime.snapshot(runtime)
    assert summary.transit_returns == 1
    assert summary.migrations == 0
    assert abs(summary.material_accounting_error) < 1.0e-8

    TransitAwareLivingBriarRuntime.stop(runtime)
  end
end
