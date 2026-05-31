defmodule Procession.GameSessionTest do
  use ExUnit.Case, async: false

  defmodule LocationContextAssertAdapter do
    @behaviour Procession.AI

    @impl true
    def generate(prompt, _opts) do
      if prompt =~ "Current location context:" and prompt =~ "Old Road Crossroads" do
        {:ok, "I know this place."}
      else
        {:error, :missing_location_context}
      end
    end
  end

  defmodule ExplicitAdapterAssertAdapter do
    @behaviour Procession.AI

    @impl true
    def generate(prompt, opts) do
      cond do
        Keyword.get(opts, :model) != "test-model" ->
          {:error, :missing_model_opt}

        prompt =~ "Speaker:" and prompt =~ "Current location context:" ->
          {:ok, "explicit adapter received structured dialogue"}

        true ->
          {:error, :missing_structured_prompt_context}
      end
    end
  end

  defmodule GroundedContextAssertAdapter do
    @behaviour Procession.AI

    @impl true
    def generate(prompt, _opts) do
      cond do
        prompt =~ "Use only the grounded context below." and
          prompt =~
            "Do not invent names, relationships, locations, occupations, memories, or events" and
          prompt =~ "Known active entities:" and
          prompt =~ "Mira" and
          prompt =~ "npc_mira" and
          prompt =~ "role: innkeeper" and
            prompt =~ "Player message:" ->
          {:ok, "grounded dialogue received"}

        true ->
          {:error, :missing_grounded_dialogue_context}
      end
    end
  end

  alias Procession.GameSession

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)
  end

  describe "start_link/1" do
    test "starts a game session process" do
      assert {:ok, session} = GameSession.start_link()
      assert Process.alive?(session)
    end

    test "starts with a generated string session id" do
      {:ok, session} = GameSession.start_link()

      summary = GameSession.summary(session)

      assert is_binary(summary.session_id)
      assert String.starts_with?(summary.session_id, "session_")
    end

    test "allows a session id to be provided for deterministic tests" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      summary = GameSession.summary(session)

      assert summary.session_id == "session_test"
    end
  end

  describe "start_demo/1" do
    test "starts a deterministic playable demo session" do
      assert {:ok, demo} = GameSession.start_demo("a quiet frontier town")

      assert Process.alive?(demo.session)
      assert demo.summary.status == :active
      assert demo.summary.world_name == "Echoes of the Old Road"
      assert demo.player_id == "player_main"
      assert demo.player_location == "loc_crossroads"
      assert demo.active_scope == "scope_starter_area"

      assert "player_main" in demo.active_entities
      assert Enum.any?(demo.active_entities, &String.starts_with?(&1, "loc_"))
      assert Enum.any?(demo.active_entities, &String.starts_with?(&1, "npc_"))
      assert Enum.any?(demo.active_entities, &String.starts_with?(&1, "faction_"))

      assert "look" in demo.commands
      assert "wait" in demo.commands
      assert "go to Briar Village" in demo.commands
    end

    test "rejects invalid demo prompts" do
      assert GameSession.start_demo(nil) == {:error, :invalid_prompt}
      assert GameSession.start_demo(:bad_prompt) == {:error, :invalid_prompt}
      assert GameSession.start_demo(123) == {:error, :invalid_prompt}
    end
  end

  describe "summary/1" do
    test "returns initial session state as plain data" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert %{
               session_id: "session_test",
               world: nil,
               active_entities: [],
               active_scope: nil,
               status: :new
             } = GameSession.summary(session)
    end
  end

  describe "new_game/2" do
    test "creates a deterministic game through the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert summary.session_id == "session_test"
      assert summary.status == :active
      assert is_map(summary.world)
      assert is_list(summary.active_entities)
      assert length(summary.active_entities) > 0
    end

    test "stores the generated game summary in session state" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, new_game_summary} = GameSession.new_game(session, "a quiet frontier town")
      session_summary = GameSession.summary(session)

      assert session_summary.world == new_game_summary.world
      assert session_summary.status == :active
    end

    test "tracks generated entity ids as active session entities" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert Enum.any?(summary.active_entities, &String.starts_with?(&1, "loc_"))
      assert Enum.any?(summary.active_entities, &String.starts_with?(&1, "npc_"))
      assert Enum.any?(summary.active_entities, &String.starts_with?(&1, "faction_"))
    end

    test "generated entities are live after session game creation" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert Enum.all?(summary.active_entities, fn entity_id ->
               Procession.EntitySupervisor.exists?(entity_id)
             end)
    end

    test "includes world name and active entity count after game creation" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert summary.world_name == "Echoes of the Old Road"
      assert summary.active_entity_count == length(summary.active_entities)
    end
  end

  describe "active scope" do
    test "starts without an active scope before game creation" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      summary = GameSession.summary(session)

      assert summary.active_scope == nil
    end

    test "sets a starter active scope when creating a new game" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert summary.active_scope == "scope_starter_area"
    end

    test "stores active scope in session summary after game creation" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      session_summary = GameSession.summary(session)

      assert session_summary.active_scope == "scope_starter_area"
    end
  end

  describe "active_entities/1" do
    test "returns active session entity ids after creating a game" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert GameSession.active_entities(session) == summary.active_entities
    end

    test "returns an empty list before a game is created" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert GameSession.active_entities(session) == []
    end
  end

  describe "owns_entity?/2" do
    test "returns true for session-owned entities" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      owned_entity = hd(summary.active_entities)

      assert GameSession.owns_entity?(session, owned_entity)
    end

    test "returns false for unknown entities" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      refute GameSession.owns_entity?(session, "npc_not_real")
    end

    test "returns false for invalid entity ids" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      refute GameSession.owns_entity?(session, nil)
      refute GameSession.owns_entity?(session, :npc_mira)
      refute GameSession.owns_entity?(session, 123)
    end
  end

  describe "cleanup/1" do
    test "stops session-owned entities" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert Enum.all?(summary.active_entities, fn entity_id ->
               Procession.EntitySupervisor.exists?(entity_id)
             end)

      cleanup_summary = GameSession.cleanup(session)

      assert cleanup_summary.status == :cleaned_up
      assert Enum.sort(cleanup_summary.stopped) == Enum.sort(summary.active_entities)
      assert cleanup_summary.missing == []

      assert eventually_all_entities_stopped?(summary.active_entities)
    end

    test "marks the session as cleaned up" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")
      GameSession.cleanup(session)

      session_summary = GameSession.summary(session)

      assert session_summary.status == :cleaned_up
    end

    test "retains owned entity ids after cleanup for inspection" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")
      GameSession.cleanup(session)

      assert GameSession.active_entities(session) == summary.active_entities
    end

    test "is safe to call more than once" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      first_cleanup = GameSession.cleanup(session)
      second_cleanup = GameSession.cleanup(session)

      assert Enum.sort(first_cleanup.stopped) == Enum.sort(summary.active_entities)
      assert second_cleanup.status == :cleaned_up
    end

    test "does not crash if an owned entity is already stopped" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      [already_stopped | _rest] = summary.active_entities
      :ok = Procession.EntitySupervisor.stop_entity(already_stopped)

      cleanup_summary = GameSession.cleanup(session)

      assert already_stopped in cleanup_summary.missing
      assert cleanup_summary.status == :cleaned_up
    end

    test "session process remains alive after cleanup" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      GameSession.cleanup(session)

      assert Process.alive?(session)
    end
  end

  describe "session and clock relationship" do
    test "world clock ticks session-created entities" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, session_summary} = GameSession.new_game(session, "a quiet frontier town")

      {:ok, clock} = Procession.WorldClock.start_link(name: nil)

      assert {:ok, tick_summary} = Procession.WorldClock.tick(clock)

      assert tick_summary.entities_considered == length(session_summary.active_entities)
      assert tick_summary.entities_ticked == 1

      assert Enum.any?(tick_summary.successful_actions, fn action ->
               action.action == :send_message and
                 action.from == "npc_tobin" and
                 action.to == "npc_mira"
             end)

      assert Enum.all?(tick_summary.skipped_actions, fn action ->
               action.status == :skipped and action.reason == :entity_not_tickable
             end)

      assert is_list(tick_summary.actions)
      assert is_list(tick_summary.failed_actions)
    end

    test "session cleanup removes entities from future world clock ticks" do
      {:ok, session} = GameSession.start_link(session_id: "session_id")
      {:ok, session_summary} = GameSession.new_game(session, "a quiet frontier town")

      {:ok, clock} = Procession.WorldClock.start_link(name: nil)

      assert {:ok, before_cleanup_tick} = Procession.WorldClock.tick(clock)
      assert before_cleanup_tick.entities_considered == length(session_summary.active_entities)
      assert before_cleanup_tick.entities_ticked == 1
      assert length(before_cleanup_tick.skipped_actions) > 0

      cleanup_summary = GameSession.cleanup(session)

      assert cleanup_summary.status == :cleaned_up

      Process.sleep(10)

      assert {:ok, after_cleanup_tick} = Procession.WorldClock.tick(clock)
      assert after_cleanup_tick.entities_considered == 0
      assert after_cleanup_tick.entities_ticked == 0
    end

    test "session talk_to passes explicit AI adapter options through dialogue boundary" do
      {:ok, session} = GameSession.start_link()
      {:ok, _summary} = GameSession.new_game(session, "anything")

      assert {:ok, "explicit adapter received structured dialogue"} =
               GameSession.talk_to(
                 session,
                 "npc_mira",
                 "What do you know about Tobin?",
                 adapter: __MODULE__.ExplicitAdapterAssertAdapter,
                 model: "test-model"
               )
    end
  end

  describe "look/2" do
    test "looks at a session-owned live entity" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = hd(summary.active_entities)

      assert {:ok, look_summary} = GameSession.look(session, entity_id)
      assert look_summary.id == entity_id
      assert is_binary(look_summary.name)
    end

    test "rejects an entity id not owned by the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_in_session} = GameSession.look(session, "npc_not_owned")
    end

    test "rejects invalid entity ids" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :entity_not_in_session} = GameSession.look(session, nil)
      assert {:error, :entity_not_in_session} = GameSession.look(session, :npc_mira)
      assert {:error, :entity_not_in_session} = GameSession.look(session, 123)
    end

    test "returns entity_not_found for a session-owned entity that is no longer live" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = hd(summary.active_entities)

      :ok = Procession.EntitySupervisor.stop_entity(entity_id)

      assert {:error, :entity_not_found} = GameSession.look(session, entity_id)
    end
  end

  describe "ask_about/3" do
    test "asks about memories for a session-owned live entity" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok, memories} = GameSession.ask_about(session, entity_id, "road")
      assert is_list(memories)
    end

    test "rejects memory queries for an entity id not owned by the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_in_session} =
               GameSession.ask_about(session, "npc_not_owned", "road")
    end

    test "rejects invalid entity ids before querying memories" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :entity_not_in_session} = GameSession.ask_about(session, nil, "road")

      assert {:error, :entity_not_in_session} = GameSession.ask_about(session, :npc_mira, "road")

      assert {:error, :entity_not_in_session} = GameSession.ask_about(session, 123, "road")
    end

    test "delegates invalid topics to the global game API for owned entities" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:error, :invalid_topic} = GameSession.ask_about(session, entity_id, nil)
    end

    test "returns entity_not_found for a session-owned entity that is no longer live" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      :ok = Procession.EntitySupervisor.stop_entity(entity_id)

      assert {:error, :entity_not_found} = GameSession.ask_about(session, entity_id, "road")
    end
  end

  describe "talk_to/4" do
    test "talks to a session-owned live NPC" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      npc_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok, response} =
               GameSession.talk_to(session, npc_id, "Hello there.",
                 adapter: Procession.AI.FakeAdapter
               )

      assert is_binary(response)
    end

    test "rejects dialogue with an entity id not owned by the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_in_session} =
               GameSession.talk_to(
                 session,
                 "npc_not_owned",
                 "Hello there.",
                 adapter: Procession.AI.FakeAdapter
               )
    end

    test "rejects invalid entity ids before dialogue" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :entity_not_in_session} =
               GameSession.talk_to(session, nil, "Hello.", adapter: Procession.AI.FakeAdapter)

      assert {:error, :entity_not_in_session} =
               GameSession.talk_to(session, :npc_mira, "Hello.",
                 adapter: Procession.AI.FakeAdapter
               )

      assert {:error, :entity_not_in_session} =
               GameSession.talk_to(session, 123, "Hello.", adapter: Procession.AI.FakeAdapter)
    end

    test "delegates invalid messages to the global game API for owned entities" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      npc_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:error, :invalid_message} =
               GameSession.talk_to(session, npc_id, nil, adapter: Procession.AI.FakeAdapter)
    end

    test "returns entity_not_found for a session-owned NPC that is no longer live" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      npc_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      :ok = Procession.EntitySupervisor.stop_entity(npc_id)

      assert {:error, :entity_not_found} =
               GameSession.talk_to(session, npc_id, "Hello?", adapter: Procession.AI.FakeAdapter)
    end

    test "rejects dialogue with the player entity" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_talkable} =
               GameSession.talk_to(
                 session,
                 summary.player_id,
                 "Hello, me.",
                 adapter: Procession.AI.FakeAdapter
               )
    end

    test "session talk_to can opt into grounded dialogue context" do
      {:ok, session} = GameSession.start_link()
      {:ok, _summary} = GameSession.new_game(session, "anything")

      assert {:ok, "grounded dialogue received"} =
               GameSession.talk_to(
                 session,
                 "npc_tobin",
                 "Who is Mira?",
                 adapter: __MODULE__.GroundedContextAssertAdapter,
                 grounded_context: true,
                 memory_query: "mine"
               )
    end
  end

  describe "recent_events/2" do
    test "returns recent events for a session-owned live entity" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = hd(summary.active_entities)

      assert {:ok, events} = GameSession.recent_events(session, entity_id)
      assert is_list(events)
    end

    test "rejects event inspection for an entity id not owned by the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:error, :entity_not_in_session} =
               GameSession.recent_events(session, "npc_not_owned")
    end

    test "rejects invalid entity ids before inspecting events" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :entity_not_in_session} = GameSession.recent_events(session, nil)

      assert {:error, :entity_not_in_session} = GameSession.recent_events(session, :npc_mira)

      assert {:error, :entity_not_in_session} = GameSession.recent_events(session, 123)
    end

    test "returns entity_not_found for a session-owned entity that is no longer live" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = hd(summary.active_entities)

      :ok = Procession.EntitySupervisor.stop_entity(entity_id)

      assert {:error, :entity_not_found} = GameSession.recent_events(session, entity_id)
    end
  end

  describe "tick/1" do
    test "ticks world behavior through the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, session_summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, tick_summary} = GameSession.tick(session)

      assert tick_summary.entities_considered == length(session_summary.active_entities)
      assert tick_summary.entities_ticked == 1

      assert Enum.any?(tick_summary.successful_actions, fn action ->
               action.action == :send_message and
                 action.from == "npc_tobin" and
                 action.to == "npc_mira"
             end)

      assert is_list(tick_summary.actions)
      assert is_list(tick_summary.successful_actions)
      assert is_list(tick_summary.failed_actions)
    end

    test "stores the latest tick summary in session state" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, tick_summary} = GameSession.tick(session)

      session_summary = GameSession.summary(session)

      assert session_summary.last_tick_summary == tick_summary
    end

    test "tick only ticks session-owned entities" do
      assert {:ok, session} = GameSession.start_link(session_id: "session_test")
      assert {:ok, _summary} = GameSession.new_game(session, "anything")

      assert {:ok, _outside_pid} =
               Procession.EntitySupervisor.start_npc("npc_outside_session", %{
                 name: "Outside Session",
                 location: "loc_nowhere",
                 metadata: %{
                   behaviors: [
                     %{
                       trigger: :world_tick,
                       action: :change_status,
                       status: :busy
                     }
                   ]
                 }
               })

      assert {:ok, tick_summary} = GameSession.tick(session)

      ticked_ids =
        tick_summary.actions
        |> Enum.map(fn action ->
          Map.get(action, :entity_id) || Map.get(action, :from)
        end)
        |> Enum.uniq()

      refute "npc_outside_session" in ticked_ids

      outside_state = Procession.Entity.get_state("npc_outside_session")
      assert outside_state.status == :idle
    end
  end

  describe "perform/3" do
    test "performs a look action through the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = hd(summary.active_entities)

      assert {:ok, look_summary} = GameSession.perform(session, :look, entity_id: entity_id)

      assert look_summary.id == entity_id
    end

    test "performs an ask_about action through the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      npc_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok, memories} =
               GameSession.perform(session, :ask_about, entity_id: npc_id, topic: "road")

      assert is_list(memories)
    end

    test "performs a talk_to action through the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      npc_id = Enum.find(summary.active_entities, &String.starts_with?(&1, "npc_"))

      assert {:ok, response} =
               GameSession.perform(
                 session,
                 :talk_to,
                 entity_id: npc_id,
                 message: "Hello.",
                 adapter: Procession.AI.FakeAdapter
               )

      assert is_binary(response)
    end

    test "performs a recent_events action through the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      entity_id = hd(summary.active_entities)

      assert {:ok, events} = GameSession.perform(session, :recent_events, entity_id: entity_id)

      assert is_list(events)
    end

    test "performs a tick action through the session" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, tick_summary} = GameSession.perform(session, :tick)

      assert is_integer(tick_summary.entities_ticked)
      assert is_list(tick_summary.actions)
    end

    test "returns invalid_action for unsupported actions" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :invalid_action} = GameSession.perform(session, :dance_badly)
    end

    test "returns invalid_action for invalid action values" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :invalid_action} = GameSession.perform(session, "look")
    end

    test "performs a location-relative look action without an entity id" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, location_summary} = GameSession.perform(session, :look)

      assert location_summary.type == :location
      assert Map.has_key?(location_summary, :local_entities)
    end

    test "returns player_not_found for location-relative look before game creation" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :player_not_found} = GameSession.perform(session, :look)
    end

    test "returns missing_topic for ask_about without a topic" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :missing_topic} =
               GameSession.perform(session, :ask_about, entity_id: "npc_mira")
    end

    test "returns missing_message for talk_to without a message" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :missing_message} =
               GameSession.perform(session, :talk_to, entity_id: "npc_mira")
    end
  end

  describe "player entity" do
    test "creates a player entity when starting a new game" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert summary.player_id == "player_main"
      assert "player_main" in summary.active_entities
      assert Procession.EntitySupervisor.exists?("player_main")
    end

    test "session owns the player entity" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert GameSession.owns_entity?(session, "player_main")
    end
  end

  describe "player/1" do
    test "returns nil before a game is created" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert GameSession.player(session) == nil
    end

    test "returns the player id after a game is created" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert GameSession.player(session) == summary.player_id
      assert GameSession.player(session) == "player_main"
    end
  end

  describe "player_location/1" do
    test "returns player_not_found before a game is created" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :player_not_found} = GameSession.player_location(session)
    end

    test "returns the player's current location after a game is created" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, location_id} = GameSession.player_location(session)
      assert location_id in summary.world.locations
      assert String.starts_with?(location_id, "loc_")
    end

    test "returns entity_not_found when the player entity is no longer live" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      :ok = Procession.EntitySupervisor.stop_entity(summary.player_id)

      assert {:error, :entity_not_found} = GameSession.player_location(session)
    end
  end

  describe "look/1" do
    test "looks at the player's current location" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, location_summary} = GameSession.look(session)

      assert String.starts_with?(location_summary.id, "loc_")
      assert location_summary.type == :location
    end

    test "returns player_not_found before a game is created" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :player_not_found} = GameSession.look(session)
    end

    test "returns entity_not_found when the player entity is no longer live" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      :ok = Procession.EntitySupervisor.stop_entity(summary.player_id)

      assert {:error, :entity_not_found} = GameSession.look(session)
    end

    test "includes local entities at the player's current location" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, location_summary} = GameSession.look(session)

      assert Map.has_key?(location_summary, :local_entities)
      assert is_list(location_summary.local_entities)
      refute summary.player_id in location_summary.local_entities
    end

    test "location-relative look local entities match local_entities helper" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      assert {:ok, local_entities} = GameSession.local_entities(session)
      assert {:ok, location_summary} = GameSession.look(session)

      assert Enum.sort(location_summary.local_entities) == Enum.sort(local_entities)
    end
  end

  describe "travel/2" do
    test "moves the player to a reachable location" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert Procession.GameSession.player_location(session) == {:ok, "loc_crossroads"}

      assert {:ok, travel_summary} = Procession.GameSession.travel(session, "loc_briar_village")

      assert travel_summary == %{
               from: "loc_crossroads",
               to: "loc_briar_village",
               via: "village road"
             }

      assert Procession.GameSession.player_location(session) == {:ok, "loc_briar_village"}
    end

    test "rejects unreachable destinations" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert {:ok, _summary} = Procession.GameSession.travel(session, "loc_briar_village")

      assert Procession.GameSession.travel(session, "loc_silent_mine") ==
               {:error, :destination_unreachable}

      assert Procession.GameSession.player_location(session) == {:ok, "loc_briar_village"}
    end

    test "rejects unknown destinations" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert Procession.GameSession.travel(session, "loc_nowhere") ==
               {:error, :unknown_destination}
    end

    test "rejects non-location destinations" do
      assert {:ok, session} = Procession.GameSession.start_link()
      assert {:ok, _summary} = Procession.GameSession.new_game(session, "anything")

      assert Procession.GameSession.travel(session, "npc_tobin") ==
               {:error, :unknown_destination}
    end

    test "requires a player entity" do
      assert {:ok, session} = Procession.GameSession.start_link()

      assert Procession.GameSession.travel(session, "loc_briar_village") ==
               {:error, :player_not_found}
    end
  end

  describe "local_entities/1" do
    test "returns player_not_found before a game is created" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")

      assert {:error, :player_not_found} = GameSession.local_entities(session)
    end

    test "returns session-owned entities at the player's current location" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      {:ok, location_id} = GameSession.player_location(session)

      assert {:ok, local_entities} = GameSession.local_entities(session)

      assert is_list(local_entities)
      refute summary.player_id in local_entities

      assert Enum.all?(local_entities, fn entity_id ->
               {:ok, entity_summary} = GameSession.look(session, entity_id)
               entity_summary.location == location_id
             end)
    end

    test "does not include entities from other locations" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, summary} = GameSession.new_game(session, "a quiet frontier town")

      {:ok, player_location} = GameSession.player_location(session)
      other_location = Enum.find(summary.world.locations, &(&1 != player_location))

      npc_id =
        Enum.find(summary.world.npcs, fn entity_id ->
          {:ok, entity_summary} = GameSession.look(session, entity_id)
          entity_summary.location != player_location
        end)

      assert other_location != nil
      assert npc_id != nil

      assert {:ok, local_entities} = GameSession.local_entities(session)

      refute npc_id in local_entities
    end

    test "does not include unknown global entities" do
      {:ok, session} = GameSession.start_link(session_id: "session_test")
      {:ok, _summary} = GameSession.new_game(session, "a quiet frontier town")

      {:ok, location_id} = GameSession.player_location(session)

      {:ok, _pid} =
        Procession.EntitySupervisor.start_npc("npc_global_intruder", %{
          name: "Global Intruder",
          location: location_id,
          status: :idle
        })

      assert {:ok, local_entities} = GameSession.local_entities(session)

      refute "npc_global_intruder" in local_entities
    end
  end

  describe "location-relative gameplay after travel" do
    test "look returns the player's new location after travel" do
      assert {:ok, session} = GameSession.start_link()
      assert {:ok, _summary} = GameSession.new_game(session, "anything")

      assert {:ok, before_travel} = GameSession.look(session)
      assert before_travel.id == "loc_crossroads"

      assert {:ok, _travel_summary} = GameSession.travel(session, "loc_briar_village")

      assert {:ok, after_travel} = GameSession.look(session)
      assert after_travel.id == "loc_briar_village"
      assert after_travel.name == "Briar Village"
    end

    test "local_entities updates after travel" do
      assert {:ok, session} = GameSession.start_link()
      assert {:ok, _summary} = GameSession.new_game(session, "anything")

      assert GameSession.local_entities(session) == {:ok, ["npc_tobin"]}

      assert {:ok, _travel_summary} = GameSession.travel(session, "loc_briar_village")

      assert GameSession.local_entities(session) == {:ok, ["npc_mira"]}
    end

    test "look local_entities updates after travel" do
      assert {:ok, session} = GameSession.start_link()
      assert {:ok, _summary} = GameSession.new_game(session, "anything")

      assert {:ok, before_travel} = GameSession.look(session)
      assert before_travel.local_entities == ["npc_tobin"]

      assert {:ok, _travel_summary} = GameSession.travel(session, "loc_briar_village")

      assert {:ok, after_travel} = GameSession.look(session)
      assert after_travel.local_entities == ["npc_mira"]
      refute "npc_tobin" in after_travel.local_entities
      refute "npc_elin" in after_travel.local_entities
    end
  end

  defp eventually_all_entities_stopped?(entity_ids, attempts \\ 10)

  defp eventually_all_entities_stopped?(_entity_ids, 0), do: false

  defp eventually_all_entities_stopped?(entity_ids, attempts) do
    if Enum.all?(entity_ids, fn entity_id ->
         not Procession.EntitySupervisor.exists?(entity_id)
       end) do
      true
    else
      Process.sleep(10)
      eventually_all_entities_stopped?(entity_ids, attempts - 1)
    end
  end
end
