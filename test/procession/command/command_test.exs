defmodule Procession.CommandTest do
  use ExUnit.Case, async: false

  alias Procession.Command
  alias Procession.GameSession

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)
  end

  describe "run/2" do
    test "rejects non-binary command input" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :invalid_command} = Command.run(session, nil)
      assert {:error, :invalid_command} = Command.run(session, :look)
      assert {:error, :invalid_command} = Command.run(session, 123)
    end

    test "rejects blank command input" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :invalid_command} = Command.run(session, "")
      assert {:error, :invalid_command} = Command.run(session, "   ")
    end

    test "returns unknown_command for unsupported commands" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :unknown_command} = Command.run(session, "dance majestically")
    end

    test "runs look against the player's current location" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      {:ok, player_location} = GameSession.player_location(session)

      assert {:ok, %{command: :look, result: result}} = Command.run(session, "look")

      assert result.id == player_location
      assert is_binary(result.name)
      assert is_list(result.local_entities)
    end

    test "trims command input before parsing" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, %{command: :look, result: result}} = Command.run(session, "  look  ")

      assert is_binary(result.id)
    end
  end
end
