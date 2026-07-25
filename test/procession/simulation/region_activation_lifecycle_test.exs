defmodule Procession.Simulation.RegionActivationLifecycleTest do
  use ExUnit.Case, async: false

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.RegionActivationLifecycle

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  defp physical(id, position, inventory \\ 0.0) do
    %{id: id, position: position, energy: 0.75, mobility: 1.0, inventory: inventory}
  end

  defp stop_if_present(id) do
    if EntitySupervisor.exists?(id), do: EntitySupervisor.stop_entity(id)
  end

  test "deactivation retains only bounded social identities and activation restores them" do
    region_id = unique("activation_region")
    anchor = unique("anchor")
    partner = unique("partner")
    unanchored = unique("unanchored")

    on_exit(fn ->
      case LiveResolutionManager.fetch(region_id) do
        {:ok, region} -> Enum.each(Map.keys(region.entities), &stop_if_present/1)
        _ -> :ok
      end

      Enum.each([anchor, partner, unanchored], &stop_if_present/1)
    end)

    assert {:ok, _} =
             EntitySupervisor.start_entity(anchor, %{
               name: "Remembered Mara",
               type: :npc,
               traits: %{patience: 0.7},
               metadata: %{identity_marker: :preserve_me}
             })

    assert {:ok, _} = EntitySupervisor.start_entity(partner, %{name: "Known Partner", type: :npc})
    assert {:ok, _} = EntitySupervisor.start_entity(unanchored, %{name: "Disposable Detail", type: :npc})

    Entity.send_message(anchor, %{type: :observation, content: "old river path", importance: 0.8})
    assert length(Entity.get_state(anchor).short_memory) == 1

    relation_key = {anchor, partner, {:movement_attempt, :east}}

    region =
      MultiResolutionRegion.new(
        id: region_id,
        tick: 12,
        entities: [
          physical(anchor, {1, 1}, 0.2),
          physical(partner, {2, 1}, 0.1),
          physical(unanchored, {3, 1}, 0.05)
        ],
        resources: [%{id: unique("store"), position: {4, 4}, quantity: 2.0}],
        social_relations: %{
          relation_key => %{
            expectation: 0.7,
            confidence: 0.8,
            persistence: 1.2,
            extreme_imprint: 0.0,
            exposure: 5.0,
            last_tick: 12
          }
        },
        causal_flags: [:old_flood]
      )

    assert {:ok, _} = LiveResolutionManager.put(region)

    assert {:ok, %{resolution: :inert, entity_count: 0}} =
             RegionActivationLifecycle.deactivate(region_id)

    refute EntitySupervisor.exists?(anchor)
    refute EntitySupervisor.exists?(partner)
    refute EntitySupervisor.exists?(unanchored)

    assert {:ok, archive} = RegionActivationLifecycle.archive(region_id)
    assert Map.keys(archive.snapshots) |> MapSet.new() == MapSet.new([anchor, partner])
    assert archive.population_minds.total_population == 1
    assert archive.population_minds.minded_population == 0

    assert {:ok, %{resolution: :inert, tick: 17}} =
             LiveResolutionManager.advance(region_id, 5)

    assert {:ok, %{resolution: :live, entity_count: 3}} =
             RegionActivationLifecycle.activate(region_id, 41)

    restored = Entity.get_state(anchor)
    assert restored.name == "Remembered Mara"
    assert restored.traits.patience == 0.7
    assert restored.metadata.identity_marker == :preserve_me
    assert restored.location == region_id
    assert length(restored.short_memory) == 1

    assert {:ok, refined} = LiveResolutionManager.fetch(region_id)
    assert Map.has_key?(refined.entities, anchor)
    assert Map.has_key?(refined.entities, partner)
    refute Map.has_key?(refined.entities, unanchored)
    assert :error = RegionActivationLifecycle.archive(region_id)
  end

  test "unanchored developmental minds survive through bounded population reconstruction" do
    region_id = unique("population_mind_region")
    entity_id = unique("unanchored_mind")

    on_exit(fn ->
      stop_if_present(entity_id)

      case LiveResolutionManager.fetch(region_id) do
        {:ok, region} -> Enum.each(Map.keys(region.entities), &stop_if_present/1)
        _ -> :ok
      end
    end)

    assert {:ok, _} =
             EntitySupervisor.start_entity(entity_id, %{
               name: "Developing Mind",
               type: :npc,
               sensorimotor: [micro_nodes: 64, input_width: 4, seed: 19]
             })

    Enum.each(1..12, fn _ ->
      assert {:ok, _} =
               EntitySupervisor.sensorimotor_observe(
                 entity_id,
                 [{:signal, :scarcity, 4.0}],
                 extreme_salience_threshold: 2.0
               )
    end)

    assert {:ok, before_trace} = EntitySupervisor.sensorimotor_trace(entity_id)
    assert before_trace.salience.imprint_count > 0

    region =
      MultiResolutionRegion.new(
        id: region_id,
        entities: [physical(entity_id, {1, 1})],
        resources: []
      )

    assert {:ok, _} = LiveResolutionManager.put(region)

    assert {:ok, %{resolution: :inert}} =
             RegionActivationLifecycle.deactivate(region_id,
               population_mind_cohort_limit: 2
             )

    refute EntitySupervisor.exists?(entity_id)

    assert {:ok, archive} = RegionActivationLifecycle.archive(region_id)
    assert archive.snapshots == %{}
    assert archive.mind_snapshots == %{}
    assert archive.population_minds.total_population == 1
    assert archive.population_minds.minded_population == 1
    assert length(archive.population_minds.cohorts) == 1

    assert {:ok, %{resolution: :live, entity_count: 1}} =
             RegionActivationLifecycle.activate(region_id, 77)

    assert {:ok, refined} = LiveResolutionManager.fetch(region_id)
    [new_id] = Map.keys(refined.entities)
    refute new_id == entity_id
    assert EntitySupervisor.sensorimotor_enabled?(new_id)

    assert {:ok, after_trace} = EntitySupervisor.sensorimotor_trace(new_id)
    assert after_trace.salience.imprint_count > 0
    assert after_trace.cycles == before_trace.cycles
  end

  test "mixed unanchored populations preserve approximate mind prevalence" do
    region_id = unique("mixed_population_region")
    ids = for index <- 1..10, do: unique("resident_#{index}")

    on_exit(fn ->
      Enum.each(ids, &stop_if_present/1)

      case LiveResolutionManager.fetch(region_id) do
        {:ok, region} -> Enum.each(Map.keys(region.entities), &stop_if_present/1)
        _ -> :ok
      end
    end)

    Enum.each(Enum.with_index(ids, 1), fn {id, index} ->
      attrs =
        if index <= 4 do
          %{name: id, type: :npc, sensorimotor: [micro_nodes: 32, input_width: 3, seed: index]}
        else
          %{name: id, type: :npc}
        end

      assert {:ok, _} = EntitySupervisor.start_entity(id, attrs)
    end)

    region =
      MultiResolutionRegion.new(
        id: region_id,
        entities: Enum.with_index(ids, fn id, index -> physical(id, {index, 0}) end),
        resources: []
      )

    assert {:ok, _} = LiveResolutionManager.put(region)
    assert {:ok, %{resolution: :inert}} = RegionActivationLifecycle.deactivate(region_id)
    assert {:ok, archive} = RegionActivationLifecycle.archive(region_id)
    assert archive.population_minds.total_population == 10
    assert archive.population_minds.minded_population == 4

    assert {:ok, %{resolution: :live, entity_count: 10}} =
             RegionActivationLifecycle.activate(region_id, 123)

    assert {:ok, refined} = LiveResolutionManager.fetch(region_id)
    minded = Enum.count(Map.keys(refined.entities), &EntitySupervisor.sensorimotor_enabled?/1)
    assert minded in 2..6
  end

  test "activation collision leaves the inactive region and archive unchanged" do
    region_id = unique("collision_region")
    anchor = unique("collision_anchor")
    partner = unique("collision_partner")

    on_exit(fn ->
      stop_if_present(anchor)
      stop_if_present(partner)

      case LiveResolutionManager.fetch(region_id) do
        {:ok, region} -> Enum.each(Map.keys(region.entities), &stop_if_present/1)
        _ -> :ok
      end
    end)

    assert {:ok, _} = EntitySupervisor.start_entity(anchor, %{name: "Original", type: :npc})
    assert {:ok, _} = EntitySupervisor.start_entity(partner, %{name: "Partner", type: :npc})

    region =
      MultiResolutionRegion.new(
        id: region_id,
        entities: [physical(anchor, {1, 1}), physical(partner, {2, 1})],
        resources: [],
        social_relations: %{
          {anchor, partner, :co_presence} => %{
            expectation: 0.5,
            confidence: 0.8,
            persistence: 1.0,
            extreme_imprint: 0.0,
            exposure: 3.0,
            last_tick: 0
          }
        }
      )

    assert {:ok, _} = LiveResolutionManager.put(region)
    assert {:ok, %{resolution: :inert}} = RegionActivationLifecycle.deactivate(region_id)
    assert {:ok, before_archive} = RegionActivationLifecycle.archive(region_id)

    assert {:ok, _} = EntitySupervisor.start_entity(anchor, %{name: "Collision", type: :npc})

    assert {:error, {:entity_id_collisions, collisions}} =
             RegionActivationLifecycle.activate(region_id, 7)

    assert anchor in collisions
    assert Entity.get_state(anchor).name == "Collision"
    assert {:ok, %{resolution: :inert}} = LiveResolutionManager.fetch(region_id)
    assert {:ok, ^before_archive} = RegionActivationLifecycle.archive(region_id)
    refute EntitySupervisor.exists?(partner)

    assert :ok = EntitySupervisor.stop_entity(anchor)

    assert {:ok, %{resolution: :live, entity_count: 2}} =
             RegionActivationLifecycle.activate(region_id, 7)

    assert Entity.get_state(anchor).name == "Original"
    assert EntitySupervisor.exists?(partner)
  end
end
