defmodule Procession.EntityCapabilitiesTest do
  use ExUnit.Case

  alias Procession.EntityCapabilities

  describe "first-pass entity capability rules" do
    test "NPCs are inspectable, talkable, askable, and tickable" do
      npc = %{type: :npc}

      assert EntityCapabilities.inspectable?(npc)
      assert EntityCapabilities.talkable?(npc)
      assert EntityCapabilities.askable?(npc)
      assert EntityCapabilities.tickable?(npc)

      refute EntityCapabilities.movable?(npc)
      refute EntityCapabilities.location?(npc)
    end

    test "players are inspectable and movable" do
      player = %{type: :player}

      assert EntityCapabilities.inspectable?(player)
      assert EntityCapabilities.movable?(player)

      refute EntityCapabilities.talkable?(player)
      refute EntityCapabilities.askable?(player)
      refute EntityCapabilities.tickable?(player)
      refute EntityCapabilities.location?(player)
    end

    test "locations are inspectable and recognized as locations" do
      location = %{type: :location}

      assert EntityCapabilities.inspectable?(location)
      assert EntityCapabilities.location?(location)

      refute EntityCapabilities.talkable?(location)
      refute EntityCapabilities.askable?(location)
      refute EntityCapabilities.movable?(location)
      refute EntityCapabilities.tickable?(location)
    end

    test "factions are inspectable but not directly talkable or movable" do
      faction = %{type: :faction}

      assert EntityCapabilities.inspectable?(faction)

      refute EntityCapabilities.talkable?(faction)
      refute EntityCapabilities.askable?(faction)
      refute EntityCapabilities.movable?(faction)
      refute EntityCapabilities.location?(faction)
      refute EntityCapabilities.tickable?(faction)
    end

    test "unknown or malformed entities have no capabilities" do
      unknown = %{type: :dragon}

      refute EntityCapabilities.inspectable?(unknown)
      refute EntityCapabilities.talkable?(unknown)
      refute EntityCapabilities.askable?(unknown)
      refute EntityCapabilities.movable?(unknown)
      refute EntityCapabilities.location?(unknown)
      refute EntityCapabilities.tickable?(unknown)

      refute EntityCapabilities.inspectable?(%{})
      refute EntityCapabilities.talkable?(nil)
    end
  end
end
