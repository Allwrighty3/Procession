defmodule Procession.Simulation.InTransitCognitionTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.CognitiveMaterialKernel
  alias Procession.Simulation.TransitAwareLivingBriarRuntime

  test "a body outside every region receives and commits a transit cognitive opportunity" do
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
        heading: :forward,
        paused?: false
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

    assert decision.primitive in [:continue_transit, :pause_transit, :reverse_transit]

    summary = TransitAwareLivingBriarRuntime.snapshot(runtime)
    assert summary.in_transit_decisions == 1
    assert summary.transit_minds_committed?
    assert map_size(summary.resident_processes) == 1
    assert abs(summary.material_accounting_error) < 1.0e-8

    TransitAwareLivingBriarRuntime.stop(runtime)
  end

  test "reverse heading returns a traveler to the source boundary" do
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
        accumulated: 1.0,
        extent: 4.0,
        body: body,
        heading: :reverse,
        paused?: false
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
