defmodule Procession.Simulation.CoarseIdentityCommitmentAdvanceTest do
  use ExUnit.Case, async: false

  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive, :monotonic])}"

  test "coarse advancement updates anchored consumption and energy before migration" do
    manager = String.to_atom(unique("advance_manager"))
    source_id = unique("source")
    destination_id = unique("destination")
    mover = unique("mover")
    partner = unique("partner")

    assert {:ok, _pid} = LiveResolutionManager.start_link(name: manager)

    source =
      MultiResolutionRegion.new(
        id: source_id,
        entities: [
          %{id: mover, position: {1, 1}, energy: 0.8, mobility: 1.0, inventory: 0.0, consumed: 0.0},
          %{id: partner, position: {2, 1}, energy: 0.8, mobility: 1.0, inventory: 0.0, consumed: 0.0}
        ],
        resources: [%{id: unique("food"), position: {1, 1}, quantity: 1.0}],
        social_relations: %{
          {mover, partner, :presence} => %{confidence: 1.0, persistence: 1.0}
        }
      )
      |> LiveResolutionManager.compress_region()
      |> MultiResolutionRegion.make_inert()

    destination =
      MultiResolutionRegion.new(id: destination_id, entities: [])
      |> LiveResolutionManager.compress_region()
      |> MultiResolutionRegion.make_inert()

    assert {:ok, _} = LiveResolutionManager.put(source, manager)
    assert {:ok, _} = LiveResolutionManager.put(destination, manager)

    before = source.summary.identity_commitments[mover]

    assert {:ok, _} =
             LiveResolutionManager.advance(
               source_id,
               10,
               [per_entity_demand: 0.01, satisfied_energy_gain: 0.002, energy_decay: 0.0],
               manager
             )

    assert {:ok, advanced} = LiveResolutionManager.fetch(source_id, manager)
    after_advance = advanced.summary.identity_commitments[mover]
    assert after_advance.consumed > before.consumed
    assert after_advance.energy > before.energy

    assert {:ok, _} =
             LiveResolutionManager.transfer_identity(
               mover,
               source_id,
               destination_id,
               [],
               manager
             )

    assert {:ok, destination_after} = LiveResolutionManager.fetch(destination_id, manager)
    moved = destination_after.summary.identity_commitments[mover]
    assert_in_delta moved.consumed, after_advance.consumed, 1.0e-9
    assert_in_delta moved.energy, after_advance.energy, 1.0e-9
  end
end
