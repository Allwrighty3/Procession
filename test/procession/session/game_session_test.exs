defmodule Procession.GameSessionTest do
  use ExUnit.Case, async: false

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

      refute Enum.any?(summary.active_entities, fn entity_id ->
               Procession.EntitySupervisor.exists?(entity_id)
             end)
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

      assert tick_summary.entities_ticked >= length(session_summary.active_entities)
      assert is_list(tick_summary.actions)
      assert is_list(tick_summary.failed_actions)
    end

    test "session cleanup removes entities from future world clock ticks" do
      {:ok, session} = GameSession.start_link(session_id: "session_id")
      {:ok, session_summary} = GameSession.new_game(session, "a quiet frontier town")

      {:ok, clock} = Procession.WorldClock.start_link(name: nil)

      assert {:ok, before_cleanup_tick} = Procession.WorldClock.tick(clock)
      assert before_cleanup_tick.entities_ticked >= length(session_summary.active_entities)

      cleanup_summary = GameSession.cleanup(session)

      assert cleanup_summary.status == :cleaned_up

      Process.sleep(10)

      assert {:ok, after_cleanup_tick} = Procession.WorldClock.tick(clock)
      assert after_cleanup_tick.entities_ticked == 0
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
end
