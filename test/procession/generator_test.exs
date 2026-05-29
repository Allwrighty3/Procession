defmodule Procession.GeneratorTest do
  use ExUnit.Case

  test "generate_world returns a world blueprint" do
    assert {:ok, blueprint} =
             Procession.Generator.generate_world("a frontier village near a haunted mine")

    assert blueprint.name == "Echoes of the Old Road"
    assert blueprint.description =~ "frontier region"
    assert blueprint.prompt == "a frontier village near a haunted mine"
  end

  test "generated blueprint has the expected top-level shape" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert Map.has_key?(blueprint, :name)
    assert Map.has_key?(blueprint, :description)
    assert Map.has_key?(blueprint, :prompt)
    assert Map.has_key?(blueprint, :locations)
    assert Map.has_key?(blueprint, :npcs)
    assert Map.has_key?(blueprint, :factions)
    assert Map.has_key?(blueprint, :relationships)
    assert Map.has_key?(blueprint, :starter_memories)
  end

  test "generated blueprint includes a tiny starter world" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert length(blueprint.locations) == 3
    assert length(blueprint.npcs) == 3
    assert length(blueprint.factions) == 1
    assert length(blueprint.relationships) >= 1
    assert length(blueprint.starter_memories) >= 1
  end

  test "generated entity IDs use existing string ID conventions" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert Enum.all?(blueprint.locations, fn location ->
             String.starts_with?(location.id, "loc_")
           end)

    assert Enum.all?(blueprint.npcs, fn npc ->
             String.starts_with?(npc.id, "npc_")
           end)

    assert Enum.all?(blueprint.factions, fn faction ->
             String.starts_with?(faction.id, "faction_")
           end)
  end

  test "generated NPCs reference known locations" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    location_ids = Enum.map(blueprint.locations, & &1.id)

    assert Enum.all?(blueprint.npcs, fn npc ->
             npc.location in location_ids
           end)
  end

  test "generated relationships reference known enitty IDs" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    entity_ids =
      blueprint.locations
      |> Enum.concat(blueprint.npcs)
      |> Enum.concat(blueprint.factions)
      |> Enum.map(& &1.id)

    assert Enum.all?(blueprint.relationships, fn relationship ->
             relationship.from in entity_ids and relationship.to in entity_ids
           end)
  end

  test "start memories reference known NPCs" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    npc_ids = Enum.map(blueprint.npcs, & &1.id)

    assert Enum.all?(blueprint.starter_memories, fn memory ->
             memory.entity_id in npc_ids
           end)
  end

  test "generation is deterministic" do
    prompt = "a frontier village near a haunted mine"

    assert Procession.Generator.generate_world(prompt) ==
             Procession.Generator.generate_world(prompt)
  end

  test "generate_world rejects invalid prompts" do
    assert Procession.Generator.generate_world(nil) == {:error, :invalid_prompt}
    assert Procession.Generator.generate_world(:not_a_prompt) == {:error, :invalid_prompt}
    assert Procession.Generator.generate_world(123) == {:error, :invalid_prompt}
  end
end
