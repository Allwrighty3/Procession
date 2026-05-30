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

    test "runs wait as a session tick" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, %{command: :wait, result: result}} = Command.run(session, "wait")

      assert is_integer(result.entities_ticked)
      assert is_list(result.actions)
      assert is_list(result.failed_actions)
    end

    test "trims wait command input" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, %{command: :wait, result: result}} = Command.run(session, "  wait  ")

      assert is_integer(result.entities_ticked)
    end

    test "runs events for against an exact session-owned entity name" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))
      target_state = Procession.Entity.get_state(target_id)

      assert {:ok,
              %{
                command: :recent_events,
                entity_id: ^target_id,
                result: events
              }} = Command.run(session, "events for #{target_state.name}")

      assert is_list(events)
    end

    test "runs events for against an exact session-owned entity id" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      target_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok,
              %{
                command: :recent_events,
                entity_id: ^target_id,
                result: events
              }} = Command.run(session, "events for #{target_id}")

      assert is_list(events)
    end

    test "returns missing_target for malformed events for command" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :missing_target} = Command.run(session, "events for ")
    end

    test "returns entity_not_found for events for with an unknown target" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_found} = Command.run(session, "events for Nobody")
    end
  end

  describe "travel commands" do
    test "go to moves the player to a reachable location by name" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert {:ok, result} = Procession.Command.run(session, "go to Briar Village")

      assert result.command == :travel_to
      assert result.destination == "Briar Village"
      assert result.destination_id == "loc_briar_village"

      assert result.result == %{
               from: "loc_crossroads",
               to: "loc_briar_village",
               via: "village road"
             }

      assert Procession.GameSession.player_location(session) == {:ok, "loc_briar_village"}
    end

    test "travel to moves the player to a reachable location by id" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert {:ok, result} = Procession.Command.run(session, "travel to loc_silent_mine")

      assert result.command == :travel_to
      assert result.destination == "loc_silent_mine"
      assert result.destination_id == "loc_silent_mine"

      assert result.result == %{
               from: "loc_crossroads",
               to: "loc_silent_mine",
               via: "mine road"
             }

      assert Procession.GameSession.player_location(session) == {:ok, "loc_silent_mine"}
    end

    test "travel command rejects missing destination" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert Procession.Command.run(session, "go to") == {:error, :missing_target}
      assert Procession.Command.run(session, "travel to") == {:error, :missing_target}
    end

    test "travel command rejects unreachable destinations" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert {:ok, _result} = Procession.Command.run(session, "go to Briar Village")

      assert Procession.Command.run(session, "go to Silent Mine") ==
               {:error, :destination_unreachable}
    end

    test "travel command rejects non-location entity names" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert Procession.Command.run(session, "go to Tobin") ==
               {:error, :entity_not_found}
    end
  end

  test "resolved travel commands include canonical destination name" do
    assert {:ok, demo} = GameSession.start_demo()

    assert {:ok, result} = Command.run(demo.session, "go to briar village")

    assert result.command == :travel_to
    assert result.destination == "briar village"
    assert result.destination_id == "loc_briar_village"
    assert result.destination_name == "Briar Village"
  end

  describe "Phase 13 vertical slice" do
    test "runs a playable multi-command demo sequence" do
      assert {:ok, demo} = Procession.GameSession.start_demo()
      session = demo.session

      assert {:ok, look_tobin} = Procession.Command.run(session, "look at Tobin")

      assert look_tobin.command == :look_at
      assert look_tobin.entity_id == "npc_tobin"
      assert look_tobin.result.name == "Tobin"
      assert look_tobin.result.location == "loc_crossroads"

      assert {:ok, ask_tobin} = Procession.Command.run(session, "ask Tobin about road")

      assert {:ok, talk_tobin} =
               Procession.Command.run(session, "talk to Tobin: Any news from the road?")

      assert talk_tobin.command == :talk_to
      assert talk_tobin.entity_id == "npc_tobin"
      assert talk_tobin.target == "Tobin"
      assert talk_tobin.message == "Any news from the road?"
      assert is_binary(talk_tobin.result)

      assert ask_tobin.command == :ask_about

      assert Enum.any?(ask_tobin.result, fn memory ->
               memory.content ==
                 "The old road has been quieter since the mine started echoing again."
             end)

      assert {:ok, wait_result} = Procession.Command.run(session, "wait")

      assert wait_result.command == :wait

      assert Enum.any?(wait_result.result.successful_actions, fn action ->
               action.action == :send_message and
                 action.from == "npc_tobin" and
                 action.to == "npc_mira" and
                 action.content == "Tobin quietly warned Mira that the mine road was watched."
             end)

      assert {:ok, travel_result} = Procession.Command.run(session, "go to Briar Village")

      assert travel_result.command == :travel_to
      assert travel_result.destination_id == "loc_briar_village"
      assert travel_result.result.from == "loc_crossroads"
      assert travel_result.result.to == "loc_briar_village"

      assert {:ok, look_village} = Procession.Command.run(session, "look")

      assert look_village.command == :look
      assert look_village.result.id == "loc_briar_village"
      assert look_village.result.local_entities == ["npc_mira"]

      assert {:ok, ask_mira} = Procession.Command.run(session, "ask Mira about mine")

      assert {:ok, events_mira} = Procession.Command.run(session, "events for Mira")

      assert events_mira.command == :recent_events
      assert events_mira.entity_id == "npc_mira"

      assert Enum.any?(events_mira.result, fn event ->
               event.content == "Tobin quietly warned Mira that the mine road was watched." and
                 event.metadata.source == :entity_tick
             end)

      assert ask_mira.command == :ask_about

      assert Enum.any?(ask_mira.result, fn memory ->
               memory.content == "Tobin quietly warned Mira that the mine road was watched." and
                 memory.metadata.source == :entity_tick
             end)
    end
  end

  test "resolves entity names case-insensitively" do
    assert {:ok, demo} = Procession.GameSession.start_demo()

    assert {:ok, result} = Command.run(demo.session, "talk to tobin: Hello")

    assert result.command == :talk_to
    assert result.target == "tobin"
    assert result.entity_id == "npc_tobin"
  end

  test "resolves location names case-insensitively" do
    assert {:ok, demo} = Procession.GameSession.start_demo()

    assert {:ok, result} = Command.run(demo.session, "go to briar village")

    assert result.command == :travel_to
    assert result.destination == "briar village"
    assert result.destination_id == "loc_briar_village"
  end

  test "resolved entity commands include canonical entity name" do
    assert {:ok, demo} = Procession.GameSession.start_demo()

    assert {:ok, result} = Command.run(demo.session, "talk to tobin: hello")

    assert result.command == :talk_to
    assert result.target == "tobin"
    assert result.entity_id == "npc_tobin"
    assert result.entity_name == "Tobin"
  end

  test "ask command rejects non-askable entity names" do
    assert {:ok, demo} = Procession.GameSession.start_demo()

    assert Procession.Command.run(demo.session, "ask Roadwardens about road") ==
             {:error, :entity_not_askable}
  end

  test "look command includes readable local entity names for display" do
    assert {:ok, demo} = Procession.GameSession.start_demo()

    assert {:ok, result} = Procession.Command.run(demo.session, "look")

    assert result.result.local_entities == ["npc_tobin"]
    assert result.result.local_entity_names == ["Tobin"]
  end
end
