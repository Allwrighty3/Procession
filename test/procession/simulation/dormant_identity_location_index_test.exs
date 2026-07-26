defmodule Procession.Simulation.DormantIdentityLocationIndexTest do
  use ExUnit.Case, async: false

  alias Procession.EntitySupervisor
  alias Procession.Simulation.AutomaticResolutionPolicy
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.LiveSocialPlane
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionObservationPublisher

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  test "compressed identity anchors expose bounded authoritative locations" do
    manager = String.to_atom(unique("identity_manager"))
    region_id = unique("dormant_region")

    assert {:ok, _pid} = LiveResolutionManager.start_link(name: manager)

    region =
      MultiResolutionRegion.new(
        id: region_id,
        entities: [
          %{id: "anchor", position: {0, 0}},
          %{id: "unanchored", position: {1, 0}}
        ],
        social_relations: %{
          {"anchor", "unanchored", :presence} => %{confidence: 0.8, persistence: 0.4}
        }
      )

    compressed = LiveResolutionManager.compress_region(region, summary_identity_limit: 1)
    assert {:ok, _trace} = LiveResolutionManager.put(compressed, manager)

    assert LiveResolutionManager.dormant_identity_locations(manager) == %{"anchor" => region_id}

    refined = LiveResolutionManager.refine_region(compressed, 17)
    assert {:ok, _trace} = LiveResolutionManager.put(refined, manager)
    assert LiveResolutionManager.dormant_identity_locations(manager) == %{}
  end

  test "social dependency resolves one live and one dormant anchored identity" do
    observer = unique("live_observer")
    actor = unique("dormant_actor")
    live_region = unique("live_region")
    dormant_region = unique("dormant_region")
    manager = String.to_atom(unique("identity_manager"))
    social = String.to_atom(unique("identity_social"))
    policy = String.to_atom(unique("identity_policy"))
    publisher = String.to_atom(unique("identity_publisher"))

    on_exit(fn ->
      if EntitySupervisor.exists?(observer), do: EntitySupervisor.stop_entity(observer)
    end)

    assert {:ok, _pid} = LiveResolutionManager.start_link(name: manager)
    assert {:ok, _pid} = LiveSocialPlane.start_link(name: social)
    assert {:ok, _pid} = AutomaticResolutionPolicy.start_link(name: policy)

    assert {:ok, _pid} =
             RegionObservationPublisher.start_link(
               name: publisher,
               policy_server: policy,
               social_server: social,
               resolution_server: manager
             )

    assert {:ok, _pid} =
             EntitySupervisor.start_entity(observer, %{
               name: "Observer",
               type: :npc,
               location: live_region
             })

    dormant =
      MultiResolutionRegion.new(
        id: dormant_region,
        entities: [%{id: actor, position: {0, 0}}],
        social_relations: %{
          {actor, actor, :anchor} => %{confidence: 1.0, persistence: 1.0}
        }
      )
      |> LiveResolutionManager.compress_region(summary_identity_limit: 1)

    assert {:ok, _trace} = LiveResolutionManager.put(dormant, manager)

    event = %{
      entity_id: actor,
      from: {0, 0},
      proposed: {1, 0},
      displaced?: true,
      blocked?: false,
      transferred: 0.0
    }

    Enum.each(1..4, fn tick ->
      assert {:ok, _signals, _trace} =
               LiveSocialPlane.observe(
                 social,
                 observer,
                 event,
                 tick,
                 observer_salience: 2.0,
                 social_confidence_gain: 0.35
               )
    end)

    result =
      RegionObservationPublisher.refresh(
        5,
        [regional_social_dependency_threshold: 0.05],
        publisher
      )

    assert result.published[live_region].unresolved_dependencies > 0.0
    assert result.published[dormant_region].unresolved_dependencies > 0.0
    assert result.published[dormant_region].evidence.dormant_anchors == 1
    assert result.published[dormant_region].evidence.resident_count == 0
  end
end