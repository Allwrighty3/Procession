defmodule Procession.GameSessionTest do
  use ExUnit.Case, async: false

  alias Procession.GameSession

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
end
