defmodule Procession.Simulation.AuthoritativeRegionEvidenceTest do
  use ExUnit.Case, async: false

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.AutomaticResolutionPolicy
  alias Procession.Simulation.LiveCausalWorld
  alias Procession.Simulation.LiveSocialPlane
  alias Procession.Simulation.RegionObservationPublisher

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  defp stop_if_present(id) do
    if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
  end

  test "committed physical consequences publish evidence for the actor's live region" do
    entity_id = unique("physical_evidence_actor")
    region_id = unique("physical_evidence_region")
    policy_name = String.to_atom(unique("physical_evidence_policy"))
    publisher_name = String.to_atom(unique("physical_evidence_publisher"))
    world_name = String.to_atom(unique("physical_evidence_world"))

    on_exit(fn -> stop_if_present(entity_id) end)

    assert {:ok, _} = AutomaticResolutionPolicy.start_link(name: policy_name)

    assert {:ok, publisher} =
             RegionObservationPublisher.start_link(
               name: publisher_name,
               policy_server: policy_name,
               social_server: String.to_atom(unique("absent_social"))
             )

    assert {:ok, _} =
             EntitySupervisor.start_npc(entity_id, %{
               location: region_id,
               sensorimotor: [
                 position: {0, 0},
                 field_opts: [micro_nodes: 64, input_width: 3, encoding_salt: :regional_evidence],
                 body_opts: [initial_coordination: 1.0]
               ]
             })

    assert {:ok, world} =
             LiveCausalWorld.start_link(
               name: world_name,
               kernel_opts: [
                 bounds: {0, 0},
                 entities: [%{id: entity_id, position: {0, 0}}]
               ]
             )

    assert {:ok, %{tick: 1}} =
             LiveCausalWorld.tick(world,
               region_observation_publisher: publisher,
               output_exploration: 0.0
             )

    assert %{events: %{^region_id => event}} = RegionObservationPublisher.trace(publisher)
    assert event.tick == 1
    assert event.intensity > 0.0
    assert event.intensity <= 1.0
  end

  test "directed social history becomes dependency evidence only across regions" do
    observer_id = unique("dependency_observer")
    actor_id = unique("dependency_actor")
    first_region = unique("dependency_first_region")
    second_region = unique("dependency_second_region")
    policy_name = String.to_atom(unique("dependency_policy"))
    social_name = String.to_atom(unique("dependency_social"))
    publisher_name = String.to_atom(unique("dependency_publisher"))

    on_exit(fn ->
      stop_if_present(observer_id)
      stop_if_present(actor_id)
    end)

    assert {:ok, _} = AutomaticResolutionPolicy.start_link(name: policy_name)
    assert {:ok, social} = LiveSocialPlane.start_link(name: social_name)

    assert {:ok, publisher} =
             RegionObservationPublisher.start_link(
               name: publisher_name,
               policy_server: policy_name,
               social_server: social
             )

    assert {:ok, _} = EntitySupervisor.start_npc(observer_id, %{location: first_region})
    assert {:ok, _} = EntitySupervisor.start_npc(actor_id, %{location: first_region})

    event = %{
      entity_id: actor_id,
      from: {0, 0},
      proposed: {1, 0},
      position: {1, 0},
      displaced?: true,
      blocked?: false,
      transferred: 0.0,
      observed_intensity: 1.0
    }

    assert {:ok, _signals, _trace} =
             LiveSocialPlane.observe(
               social,
               observer_id,
               event,
               1,
               observer_salience: 4.0
             )

    same_region = RegionObservationPublisher.refresh(1, [], publisher)
    assert same_region.published[first_region].unresolved_dependencies == 0.0
    assert same_region.published[first_region].evidence.social_dependencies == 0

    assert :ok = Entity.move_to(actor_id, second_region)

    separated = RegionObservationPublisher.refresh(2, [], publisher)
    assert separated.published[first_region].unresolved_dependencies > 0.0
    assert separated.published[second_region].unresolved_dependencies > 0.0
    assert separated.published[first_region].evidence.social_dependencies == 1
    assert separated.published[second_region].evidence.social_dependencies == 1
  end
end
