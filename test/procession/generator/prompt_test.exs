defmodule Procession.Generator.PromptTest do
  use ExUnit.Case

  test "world_blueprint builds a prompt from a player prompt" do
    prompt = Procession.Generator.Prompt.world_blueprint("a frontier village near a haunted mine")

    assert is_binary(prompt)
    assert prompt =~ "single-player RPG simulation"
    assert prompt =~ "Player prompt:"
    assert prompt =~ "a frontier village near a haunted mine"
  end

  test "world_blueprint includes small world requirements" do
    prompt = Procession.Generator.Prompt.world_blueprint("anything")

    assert prompt =~ "Include exactly 3 locations."
    assert prompt =~ "Include exactly 3 NPCs."
    assert prompt =~ "Include exactly 1 faction."
    assert prompt =~ "Include 1-3 relationships"
    assert prompt =~ "Include 1-3 starter memories"
    assert prompt =~ "Do not create a large world."
  end

  test "world_blueprint includes ID conventions" do
    prompt = Procession.Generator.Prompt.world_blueprint("anything")

    assert prompt =~ ~s(Location IDs must start with "loc_".)
    assert prompt =~ ~s(NPC IDs must start with "npc_".)
    assert prompt =~ ~s(Faction IDs must start with "faction_".)
  end

  test "world_blueprint includes expected top-level fields" do
    prompt = Procession.Generator.Prompt.world_blueprint("anything")

    assert prompt =~ "Expected top-level fields:"
    assert prompt =~ "- name"
    assert prompt =~ "- description"
    assert prompt =~ "- locations"
    assert prompt =~ "- npcs"
    assert prompt =~ "- factions"
    assert prompt =~ "- relationships"
    assert prompt =~ "- starter_memories"
  end

  test "world_blueprint rejects invalid prompts" do
    assert Procession.Generator.Prompt.world_blueprint(nil) == {:error, :invalid_prompt}
    assert Procession.Generator.Prompt.world_blueprint(:not_a_prompt) == {:error, :invalid_prompt}
    assert Procession.Generator.Prompt.world_blueprint(123) == {:error, :invalid_prompt}
  end
end
