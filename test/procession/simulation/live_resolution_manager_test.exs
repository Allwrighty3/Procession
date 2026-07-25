defmodule Procession.Simulation.LiveResolutionManagerTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion

  test "manager owns resolution metadata without spawning entity processes" do
    name = Module.concat(__MODULE__, Manager)
    start_supervised!({LiveResolutionManager, name: name})

    before_entities =
      Procession.EntitySupervisor.list_entities()
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    region =
      MultiResolutionRegion.new(
        id: :remote_valley,
        entities: [
          %{id: "summary_person_1", position: {1, 1}, energy: 0.7, inventory: 0.2},
          %{id: "summary_person_2", position: {2, 1}, energy: 0.8, inventory: 0.1}
        ],
        resources: [%{id: "summary_store", position: {3, 3}, quantity: 2.0}],
        social_relations: %{
          {"summary_person_1", "summary_person_2", :resource_contact} => %{
            expectation: 0.8,
            confidence: 0.9,
            persistence: 0.7,
            extreme_imprint: 1.1
          }
        },
        causal_flags: [:old_flood]
      )

    assert {:ok, %{resolution: :live}} = LiveResolutionManager.put(region, name)
    assert {:ok, %{resolution: :coarse}} = LiveResolutionManager.compress(:remote_valley, [], name)

    assert {:ok, coarse} = LiveResolutionManager.fetch(:remote_valley, name)
    assert Enum.sort(coarse.summary.identity_anchors) == ["summary_person_1", "summary_person_2"]

    assert {:ok, %{resolution: :inert}} =
             LiveResolutionManager.make_inert(:remote_valley, name)

    assert {:ok, %{resolution: :inert, tick: 25}} =
             LiveResolutionManager.advance(:remote_valley, 25, [], name)

    assert {:ok, %{resolution: :live, entity_count: 2}} =
             LiveResolutionManager.refine(:remote_valley, 42, [], name)

    assert {:ok, refined} = LiveResolutionManager.fetch(:remote_valley, name)
    assert Map.has_key?(refined.entities, "summary_person_1")
    assert Map.has_key?(refined.entities, "summary_person_2")

    assert Map.has_key?(
             refined.social_relations,
             {"summary_person_1", "summary_person_2", :resource_contact}
           )

    after_entities =
      Procession.EntitySupervisor.list_entities()
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    assert after_entities == before_entities
    assert %{remote_valley: %{resolution: :live}} = LiveResolutionManager.trace(name)
  end

  test "failed transition leaves managed state unchanged" do
    name = Module.concat(__MODULE__, FailedManager)
    start_supervised!({LiveResolutionManager, name: name})
    region = MultiResolutionRegion.new(id: :region, entities: [], resources: [])

    assert {:ok, _} = LiveResolutionManager.put(region, name)
    assert {:error, _message} = LiveResolutionManager.refine(:region, 1, [], name)
    assert {:ok, stored} = LiveResolutionManager.fetch(:region, name)
    assert stored.resolution == :live
  end
end
