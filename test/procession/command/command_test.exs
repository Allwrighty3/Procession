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

    test "runs look at against an exact session-owned entity id" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok, %{command: :look_at, target: ^target_id, result: result}} =
               Command.run(session, "look at #{target_id}")

      assert result.id == target_id
      assert is_binary(result.name)
    end

    test "trims look at target input" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok, %{command: :look_at, target: ^target_id, result: result}} =
               Command.run(session, "look at   #{target_id}   ")

      assert result.id == target_id
    end

    test "returns missing_target for malformed look at command" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :missing_target} = Command.run(session, "look at ")
      assert {:error, :missing_target} = Command.run(session, "look at    ")
    end

    test "returns entity_not_foundfor look at with an unknown exact id" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_found} = Command.run(session, "look at npc_not_owned")
    end

    test "runs look at against an exact session-owned entity name" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))
      target_state = Procession.Entity.get_state(target_id)

      assert {:ok, %{command: :look_at, entity_id: ^target_id, result: result}} =
               Command.run(session, "look at #{target_state.name}")

      assert result.id == target_id
    end

    test "prefers exact entity id over entity name" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok, %{command: :look_at, entity_id: ^target_id, result: result}} =
               Command.run(session, "look at #{target_id}")

      assert result.id == target_id
    end

    test "returns entity_not_found for unknown look at name" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_found} = Command.run(session, "look at Definitely Not A Person")
    end

    test "returns ambiguous_entity for duplicate entity names" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      {:ok, _pid} =
        Procession.EntitySupervisor.start_npc("npc_duplicate_one", %{
          name: "Duplicate Scout",
          location: "loc_crossroads",
          status: :idle
        })

      {:ok, _pid} =
        Procession.EntitySupervisor.start_npc("npc_duplicate_two", %{
          name: "Duplicate Scout",
          location: "loc_crossroads",
          status: :idle
        })

      Procession.Entity.set_metadata("npc_duplicate_one", :session_id, "session_test")
      Procession.Entity.set_metadata("npc_duplicate_two", :session_id, "session_test")

      current_entities = GameSession.active_entities(session)

      # The command resolver only searches session-owned entities, so these
      # manually-started duplicates need to be added to the session for this test.
      :sys.replace_state(session, fn state ->
        %{
          state
          | active_entities:
              ["npc_duplicate_one", "npc_duplicate_two" | current_entities]
              |> Enum.uniq()
        }
      end)

      assert {:error, {:ambiguous_entity, matches}} =
               Command.run(session, "look at Duplicate Scout")

      assert Enum.sort(matches) == ["npc_duplicate_one", "npc_duplicate_two"]
    end

    test "runs ask about against an exact session-owned entity name" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))
      target_state = Procession.Entity.get_state(target_id)

      assert {:ok,
              %{
                command: :ask_about,
                entity_id: ^target_id,
                topic: "road",
                result: memories
              }} = Command.run(session, "ask #{target_state.name} about road")

      assert is_list(memories)
    end

    test "runs ask about against an exact session-owned entity id" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok,
              %{
                command: :ask_about,
                entity_id: ^target_id,
                topic: "road",
                result: memories
              }} = Command.run(session, "ask #{target_id} about road")

      assert is_list(memories)
    end

    test "returns missing_target for malformed ask about command" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :missing_target} = Command.run(session, "ask  about road")
    end

    test "returns missing_topic for ask about with no topic" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:error, :missing_topic} = Command.run(session, "ask #{target_id} about ")
    end

    test "returns invalid_command for ask without about separator" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :invalid_command} = Command.run(session, "ask Mira road")
    end

    test "returns entity_not_found for ask about with an unknown target" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_found} = Command.run(session, "ask Nobody about road")
    end

    test "runs talk to against an exact session-owned entity name" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))
      target_state = Procession.Entity.get_state(target_id)

      assert {:ok,
              %{
                command: :talk_to,
                entity_id: ^target_id,
                message: "Hello there",
                result: response
              }} = Command.run(session, "talk to #{target_state.name}: Hello there")

      assert is_binary(response)
    end

    test "runs talk to against an exact session-owned entity id" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok,
              %{
                command: :talk_to,
                entity_id: ^target_id,
                message: "Hello there",
                result: response
              }} = Command.run(session, "talk to #{target_id}: Hello there")

      assert is_binary(response)
    end

    test "returns missing_target for malformed talk to command" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :missing_target} = Command.run(session, "talk to : Hello")
    end

    test "returns missing_message for talk to with no message" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:error, :missing_message} = Command.run(session, "talk to #{target_id}: ")
    end

    test "returns invalid_command for talk to without colon separator" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :invalid_command} = Command.run(session, "talk to Mira Hello")
    end

    test "returns entity_not_found for talk to with an unknown target" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_found} = Command.run(session, "talk to Nobody: Hello")
    end
  end
end
