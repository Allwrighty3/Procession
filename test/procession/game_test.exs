defmodule Procession.GameTest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)

    :ok
  end

  test "look returns a player-facing summary for an NPC" do
    assert {:ok, _pid} =
             Procession.EntitySupervisor.start_npc("npc_mira", %{
               name: "Mira",
               location: "loc_briar_village",
               traits: %{role: "innkeeper", temperament: "watchful"}
             })

    assert {:ok, summary} = Procession.Game.look("npc_mira")

    assert summary == %{
             id: "npc_mira",
             name: "Mira",
             type: :npc,
             location: "loc_briar_village",
             status: :idle,
             traits: %{role: "innkeeper", temperament: "watchful"},
             relationships: [],
             description: nil,
             memory_summary: %{short: 0, medium: 0, long: 0}
           }
  end

  test "look returns a player-facing summary for a faction" do
    assert {:ok, _pid} =
             Procession.EntitySupervisor.start_faction("faction_roadwardens", %{
               name: "Roadwardens",
               metadata: %{
                 description: "A loose band of locals who keep the roads safe when they can."
               }
             })

    assert {:ok, summary} = Procession.Game.look("faction_roadwardens")

    assert summary.id == "faction_roadwardens"
    assert summary.name == "Roadwardens"
    assert summary.type == :faction

    assert summary.description ==
             "A loose band of locals who keep the roads safe when they can."

    assert summary.memory_summary == %{short: 0, medium: 0, long: 0}
  end

  test "look includes relationship metadata when present" do
    assert {:ok, _pid} =
             Procession.EntitySupervisor.start_npc("npc_mira", %{
               name: "Mira",
               location: "loc_briar_village",
               metadata: %{
                 relationships: [
                   %{
                     to: "npc_tobin",
                     type: :distrusts,
                     description: "Mira thinks Tobin knows more than he admits."
                   }
                 ]
               }
             })

    assert {:ok, summary} = Procession.Game.look("npc_mira")

    assert summary.relationships == [
             %{
               to: "npc_tobin",
               type: :distrusts,
               description: "Mira thinks Tobin knows more than he admits."
             }
           ]
  end

  test "look includes description metadata when present" do
    assert {:ok, _pid} =
             Procession.EntitySupervisor.start_location("loc_crossroads", %{
               name: "Old Road Crossroads",
               metadata: %{
                 description:
                   "A muddy crossroads where merchants, pilgrims, and trouble pass through."
               }
             })

    assert {:ok, summary} = Procession.Game.look("loc_crossroads")

    assert summary.id == "loc_crossroads"
    assert summary.name == "Old Road Crossroads"
    assert summary.type == :location

    assert summary.description ==
             "A muddy crossroads where merchants, pilgrims, and trouble pass through."
  end

  test "look returns a predictable error for a missing entity" do
    assert Procession.Game.look("npc_missing") == {:error, :entity_not_found}
  end
end
