defmodule Procession.Simulation.AutomaticResolutionPolicyTest do
  use ExUnit.Case, async: false

  alias Procession.EntitySupervisor
  alias Procession.Simulation.AutomaticResolutionPolicy
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  defp physical(id) do
    %{id: id, position: {1, 1}, energy: 0.8, mobility: 1.0, inventory: 0.0}
  end

  test "relevance is grounded, recent, and observer-specific" do
    quiet = AutomaticResolutionPolicy.relevance(%{distance: 100.0}, 100)

    nearby =
      AutomaticResolutionPolicy.relevance(
        %{distance: 1.0, unresolved_dependencies: 0.7, salience: 0.8, event_intensity: 0.9, last_observed_tick: 99},
        100
      )

    stale =
      AutomaticResolutionPolicy.relevance(
        %{distance: 1.0, event_intensity: 0.9, last_observed_tick: 0},
        100,
        recency_half_life: 10.0
      )

    assert nearby > quiet
    assert nearby > stale
    assert AutomaticResolutionPolicy.relevance(%{player_present: true}, 100) > 1.0
  end

  test "hysteresis prevents immediate resolution thrashing" do
    quiet = %{distance: 1_000.0}
    relevant = %{distance: 0.0, salience: 1.0, unresolved_dependencies: 1.0}

    assert :live = AutomaticResolutionPolicy.desired_resolution(:live, quiet, 10, 0, minimum_live_ticks: 20)
    assert :compressed = AutomaticResolutionPolicy.desired_resolution(:live, quiet, 30, 0, minimum_live_ticks: 20)

    assert :compressed =
             AutomaticResolutionPolicy.desired_resolution(
               :inert,
               relevant,
               5,
               0,
               minimum_dormant_ticks: 10
             )

    assert :live =
             AutomaticResolutionPolicy.desired_resolution(
               :inert,
               relevant,
               15,
               0,
               minimum_dormant_ticks: 10
             )
  end

  test "ordinary reconciliation deactivates a quiet region and reactivates it when causally relevant" do
    region_id = unique("auto_region")
    entity_id = unique("auto_entity")

    on_exit(fn ->
      if EntitySupervisor.exists?(entity_id), do: EntitySupervisor.stop_entity(entity_id)

      case LiveResolutionManager.fetch(region_id) do
        {:ok, region} ->
          Enum.each(Map.keys(region.entities), fn id ->
            if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
          end)

        _ ->
          :ok
      end

      AutomaticResolutionPolicy.forget(region_id)
    end)

    assert {:ok, _pid} = EntitySupervisor.start_entity(entity_id, %{name: "Quiet resident", type: :npc})

    region =
      MultiResolutionRegion.new(
        id: region_id,
        entities: [physical(entity_id)],
        resources: [%{id: unique("resource"), position: {2, 2}, quantity: 1.0}]
      )

    assert {:ok, _} = LiveResolutionManager.put(region)
    assert :ok = AutomaticResolutionPolicy.observe(region_id, %{distance: 1_000.0, last_observed_tick: 0})

    results =
      AutomaticResolutionPolicy.reconcile(
        100,
        minimum_live_ticks: 0,
        minimum_dormant_ticks: 0,
        max_live_regions: 0
      )

    assert %{action: :deactivated} = Enum.find(results, &(&1.region_id == region_id))
    refute EntitySupervisor.exists?(entity_id)
    assert {:ok, %{resolution: :inert}} = LiveResolutionManager.fetch(region_id)

    assert :ok =
             AutomaticResolutionPolicy.observe(region_id, %{
               distance: 0.0,
               player_present: true,
               last_observed_tick: 101
             })

    results =
      AutomaticResolutionPolicy.reconcile(
        101,
        minimum_live_ticks: 0,
        minimum_dormant_ticks: 0,
        max_live_regions: 0
      )

    assert %{action: :activated} = Enum.find(results, &(&1.region_id == region_id))
    assert {:ok, refined} = LiveResolutionManager.fetch(region_id)
    assert refined.resolution == :live
    assert Enum.all?(Map.keys(refined.entities), &EntitySupervisor.exists?/1)
  end

  test "a live budget keeps forced regions and ranks ordinary regions by causal relevance" do
    forced = %{id: "forced", current: :inert, observation: %{player_present: true}, score: 2.0}
    high = %{id: "high", current: :live, observation: %{}, score: 0.8}
    low = %{id: "low", current: :live, observation: %{}, score: 0.1}

    ranked = [forced, high, low]

    selected =
      ranked
      |> Enum.filter(fn entry -> entry.observation[:player_present] == true end)
      |> Enum.map(& &1.id)

    assert selected == ["forced"]
    assert forced.score > high.score
    assert high.score > low.score
  end
end
