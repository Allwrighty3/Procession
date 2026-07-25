defmodule Procession.Simulation.RegionObservationPublisherTest do
  use ExUnit.Case, async: false

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.AutomaticResolutionPolicy
  alias Procession.Simulation.RegionObservationPublisher

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  defp stop_if_present(id) do
    if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
  end

  test "refresh derives player presence and region distance from live entity state" do
    player = unique("publisher_player")
    npc = unique("publisher_npc")
    player_region = unique("publisher_player_region")
    npc_region = unique("publisher_npc_region")
    policy_name = String.to_atom(unique("publisher_policy"))
    publisher_name = String.to_atom(unique("publisher"))

    on_exit(fn ->
      stop_if_present(player)
      stop_if_present(npc)
    end)

    assert {:ok, _} = AutomaticResolutionPolicy.start_link(name: policy_name)

    assert {:ok, _} =
             RegionObservationPublisher.start_link(
               name: publisher_name,
               policy_server: policy_name
             )

    assert {:ok, _} =
             EntitySupervisor.start_entity(player, %{
               name: "Player",
               type: :player,
               location: player_region
             })

    assert {:ok, _} =
             EntitySupervisor.start_entity(npc, %{
               name: "Resident",
               type: :npc,
               location: npc_region
             })

    assert :ok = RegionObservationPublisher.set_region_position(player_region, {0, 0}, publisher_name)
    assert :ok = RegionObservationPublisher.set_region_position(npc_region, {3, 4}, publisher_name)

    result = RegionObservationPublisher.refresh(10, [], publisher_name)

    assert result.published[player_region].player_present
    assert result.published[player_region].distance == 0.0
    refute result.published[npc_region].player_present
    assert_in_delta result.published[npc_region].distance, 5.0, 1.0e-9

    assert :ok = Entity.move_to(player, npc_region)
    moved = RegionObservationPublisher.refresh(11, [], publisher_name)

    refute moved.published[player_region].player_present
    assert moved.published[npc_region].player_present
    assert moved.published[npc_region].distance == 0.0
  end

  test "events and dependencies are bounded, published, and expire" do
    from_region = unique("publisher_from")
    to_region = unique("publisher_to")
    policy_name = String.to_atom(unique("publisher_policy"))
    publisher_name = String.to_atom(unique("publisher"))

    assert {:ok, _} = AutomaticResolutionPolicy.start_link(name: policy_name)

    assert {:ok, _} =
             RegionObservationPublisher.start_link(
               name: publisher_name,
               policy_server: policy_name
             )

    assert :ok = RegionObservationPublisher.publish_event(from_region, 4.0, 20, publisher_name)
    assert :ok = RegionObservationPublisher.publish_dependency(from_region, to_region, 3.0, 20, publisher_name)

    current =
      RegionObservationPublisher.refresh(
        21,
        [regional_event_ttl: 5, regional_dependency_ttl: 5],
        publisher_name
      )

    assert current.published[from_region].event_intensity == 1.0
    assert current.published[from_region].unresolved_dependencies == 1.0
    assert current.published[to_region].unresolved_dependencies == 1.0

    expired =
      RegionObservationPublisher.refresh(
        30,
        [regional_event_ttl: 5, regional_dependency_ttl: 5],
        publisher_name
      )

    refute Map.has_key?(expired.published, from_region)
    refute Map.has_key?(expired.published, to_region)
    assert %{events: %{}, dependencies: %{}} = RegionObservationPublisher.trace(publisher_name)
  end

  test "live sensorimotor salience contributes bounded regional evidence" do
    entity_id = unique("publisher_mind")
    region_id = unique("publisher_mind_region")
    policy_name = String.to_atom(unique("publisher_policy"))
    publisher_name = String.to_atom(unique("publisher"))

    on_exit(fn -> stop_if_present(entity_id) end)

    assert {:ok, _} = AutomaticResolutionPolicy.start_link(name: policy_name)

    assert {:ok, _} =
             RegionObservationPublisher.start_link(
               name: publisher_name,
               policy_server: policy_name
             )

    assert {:ok, _} =
             EntitySupervisor.start_entity(entity_id, %{
               name: "Observer",
               type: :npc,
               location: region_id,
               sensorimotor: [micro_nodes: 64, input_width: 4, seed: 31]
             })

    assert {:ok, _} =
             EntitySupervisor.sensorimotor_observe(
               entity_id,
               [{:signal, :grounded_pressure, 5.0}],
               extreme_salience_threshold: 2.0
             )

    result = RegionObservationPublisher.refresh(40, [], publisher_name)
    observation = result.published[region_id]

    assert observation.salience > 0.0
    assert observation.salience <= 1.0
    assert observation.evidence.sampled_minds == 1
    assert observation.evidence.resident_count == 1
  end
end
