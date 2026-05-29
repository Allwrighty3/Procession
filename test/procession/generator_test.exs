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

  test "generated relationships reference known entity IDs" do
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

  test "starter memories reference known NPCs" do
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

  test "generated locations include required fields" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert Enum.all?(blueprint.locations, fn location ->
             Map.has_key?(location, :id) and
               Map.has_key?(location, :name) and
               Map.has_key?(location, :type) and
               Map.has_key?(location, :description)
           end)
  end

  test "generated NPCs include required fields" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert Enum.all?(blueprint.npcs, fn npc ->
             Map.has_key?(npc, :id) and
               Map.has_key?(npc, :name) and
               Map.has_key?(npc, :type) and
               Map.has_key?(npc, :location) and
               Map.has_key?(npc, :traits)
           end)
  end

  test "generated factions include required fields" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert Enum.all?(blueprint.factions, fn faction ->
             Map.has_key?(faction, :id) and
               Map.has_key?(faction, :name) and
               Map.has_key?(faction, :type) and
               Map.has_key?(faction, :description)
           end)
  end

  test "starter memories include required fields" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert Enum.all?(blueprint.starter_memories, fn memory ->
             Map.has_key?(memory, :entity_id) and
               Map.has_key?(memory, :type) and
               Map.has_key?(memory, :content) and
               Map.has_key?(memory, :importance) and
               Map.has_key?(memory, :tags)
           end)
  end

  test "validate_blueprint accepts a generated blueprint" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert Procession.Generator.validate_blueprint(blueprint) == :ok
  end

  test "validate_blueprint rejects non-map blueprints" do
    assert Procession.Generator.validate_blueprint(nil) == {:error, :invalid_blueprint}
    assert Procession.Generator.validate_blueprint("nope") == {:error, :invalid_blueprint}
  end

  test "validate_blueprint rejects blueprints missing required fields" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    invalid_blueprint = Map.delete(blueprint, :locations)

    assert Procession.Generator.validate_blueprint(invalid_blueprint) ==
             {:error, {:missing_field, :locations}}
  end

  test "validate_blueprint rejects duplicate entity IDs" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    duplicate_location = %{
      id: "loc_crossroads",
      name: "Duplicate Crossroads",
      type: :location,
      description: "This should not be allowed."
    }

    invalid_blueprint = %{
      blueprint
      | locations: [duplicate_location | blueprint.locations]
    }

    assert Procession.Generator.validate_blueprint(invalid_blueprint) ==
             {:error, :duplicate_entity_ids}
  end

  test "validate_blueprint rejects NPCs with unknown locations" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    [first_npc | rest_npcs] = blueprint.npcs
    invalid_npc = %{first_npc | location: "loc_nowhere"}

    invalid_blueprint = %{blueprint | npcs: [invalid_npc | rest_npcs]}

    assert Procession.Generator.validate_blueprint(invalid_blueprint) ==
             {:error, {:unknown_location, invalid_npc.id, "loc_nowhere"}}
  end

  test "validate_blueprint rejects relationships with unknown entities" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    invalid_relationship = %{
      from: "npc_mira",
      to: "npc_fake",
      type: :knows,
      description: "This relationship points to a missing entity."
    }

    invalid_blueprint = %{
      blueprint
      | relationships: [invalid_relationship | blueprint.relationships]
    }

    assert Procession.Generator.validate_blueprint(invalid_blueprint) ==
             {:error, {:unknown_relationship_entity, invalid_relationship}}
  end

  test "validate_blueprint rejects invalid starter memories" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    invalid_memory = %{
      entity_id: "npc_fake",
      type: :rumor,
      content: "This memory belongs to nobody.",
      importance: 1,
      tags: []
    }

    invalid_blueprint = %{
      blueprint
      | starter_memories: [invalid_memory | blueprint.starter_memories]
    }

    assert Procession.Generator.validate_blueprint(invalid_blueprint) ==
             {:error, {:invalid_starter_memory, invalid_memory}}
  end

  test "spawn_world creates live entity processes from a blueprint" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert {:ok, summary} = Procession.Generator.spawn_world(blueprint)

    assert summary.locations == ["loc_crossroads", "loc_briar_village", "loc_silent_mine"]
    assert summary.npcs == ["npc_mira", "npc_tobin", "npc_elin"]
    assert summary.factions == ["faction_roadwardens"]

    assert Procession.EntitySupervisor.exists?("loc_crossroads")
    assert Procession.EntitySupervisor.exists?("npc_mira")
    assert Procession.EntitySupervisor.exists?("faction_roadwardens")

    Enum.each(summary.locations ++ summary.npcs ++ summary.factions, fn id ->
      Procession.EntitySupervisor.stop_entity(id)
    end)
  end

  test "spawn_world rejects invalid blueprints before spawning entities" do
    assert Procession.Generator.spawn_world(%{}) == {:error, {:missing_field, :name}}
  end

  test "spawn_world rejects non-map blueprints" do
    assert Procession.Generator.spawn_world(nil) == {:error, :invalid_blueprint}
  end

  test "spawn_world attaches starter memories to generated NPCs" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert {:ok, summary} = Procession.Generator.spawn_world(blueprint)

    assert summary.starter_memories == 2

    Process.sleep(10)

    mira_memories = Procession.Entity.recall_all("npc_mira")
    tobin_memories = Procession.Entity.recall_all("npc_tobin")

    assert Enum.any?(mira_memories, fn memory ->
             memory.content == "Tobin was seen near the Silent Mine after sundown." and
               memory.type == :rumor
           end)

    assert Enum.any?(tobin_memories, fn memory ->
             memory.content ==
               "The old road has been quieter since the mine started echoing again." and
               memory.type == :observation
           end)

    Enum.each(summary.locations ++ summary.npcs ++ summary.factions, fn id ->
      Procession.EntitySupervisor.stop_entity(id)
    end)
  end

  test "spawn_world attaches relationships to generated entity metadata" do
    assert {:ok, blueprint} = Procession.Generator.generate_world("anything")

    assert {:ok, summary} = Procession.Generator.spawn_world(blueprint)

    assert summary.relationships == 2

    mira = Procession.Entity.get_state("npc_mira")
    elin = Procession.Entity.get_state("npc_elin")

    assert Enum.any?(mira.metadata.relationships, fn relationship ->
             relationship.to == "npc_tobin" and
               relationship.type == :distrusts
           end)

    assert Enum.any?(elin.metadata.relationships, fn relationship ->
             relationship.to == "faction_roadwardens" and
               relationship.type == :member_of
           end)

    Enum.each(summary.locations ++ summary.npcs ++ summary.factions, fn id ->
      Procession.EntitySupervisor.stop_entity(id)
    end)
  end

  test "generate_world_ai returns generated text through the AI boundary" do
    assert {:ok, result} =
             Procession.Generator.generate_world_ai(
               "a frontier village near a haunted mine",
               adapter: Procession.AI.FakeAdapter
             )

    assert result.prompt =~ "small world blueprint"
    assert result.prompt =~ "a frontier village near a haunted mine"
    assert result.response =~ "AI response to:"
  end

  test "generate_world_ai rejects invalid prompts" do
    assert Procession.Generator.generate_world_ai(nil) == {:error, :invalid_prompt}
    assert Procession.Generator.generate_world_ai(:not_a_prompt) == {:error, :invalid_prompt}
    assert Procession.Generator.generate_world_ai(123) == {:error, :invalid_prompt}
  end
end
