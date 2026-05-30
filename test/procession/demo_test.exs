defmodule Procession.DemoTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Procession.Demo

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)
  end

  test "starts the deterministic playable demo" do
    assert {:ok, demo} = Demo.start()

    assert is_pid(demo.session)
    assert demo.player_id == "player_main"
    assert demo.player_location == "loc_crossroads"
    assert demo.active_scope == "scope_starter_area"
    assert "look" in demo.commands
  end

  test "runs a command against a demo map and prints readable output" do
    assert {:ok, demo} = Demo.start()

    output =
      capture_io(fn ->
        assert :ok = Demo.run(demo, "look")
      end)

    assert output =~ "Old Road Crossroads"
    assert output =~ "Exits:"
    assert output =~ "Local entities:"
  end

  test "runs a command against a session pid and prints readable output" do
    assert {:ok, demo} = Demo.start()
    session = demo.session

    output =
      capture_io(fn ->
        assert :ok = Demo.run(session, "ask Tobin about road")
      end)

    assert output =~ "Tobin remembers about road:"
    assert output =~ "The old road has been quieter"
  end

  test "returns formatted text without printing" do
    assert {:ok, demo} = Demo.start()

    text = Demo.text(demo, "look")

    assert text =~ "Old Road Crossroads"
    assert text =~ "Exits:"
  end

  test "formats command errors through the demo helper" do
    assert {:ok, demo} = Demo.start()

    output =
      capture_io(fn ->
        assert :ok = Demo.run(demo, "dance majestically")
      end)

    assert output =~ "Error: I don't know what you mean. Try `help`."
  end

  test "rejects invalid demo sessions" do
    assert Demo.run(%{}, "look") == {:error, :invalid_demo_session}
    assert Demo.text(%{}, "look") == {:error, :invalid_demo_session}
    assert Demo.command(%{}, "look") == {:error, :invalid_demo_session}
  end

  test "returns raw command results through command/2" do
    assert {:ok, demo} = Demo.start()

    assert {:ok, result} = Demo.command(demo, "look")

    assert result.command == :look
    assert result.result.name == "Old Road Crossroads"
  end

  test "starts a quiet demo and returns only the session pid" do
    output =
      capture_io(fn ->
        session = Demo.start_quiet()

        assert is_pid(session)
      end)

    assert output =~ "Procession demo started."
    assert output =~ "look at Tobin"
    assert output =~ "ask Mira about mine"
  end

  test "runs talk to through the demo helper" do
    assert {:ok, demo} = Demo.start()

    output =
      capture_io(fn ->
        assert :ok = Demo.run(demo, "talk to Tobin: Hello there.")
      end)

    assert output =~ "Tobin says:"
  end

  test "runs recent events through the demo helper" do
    assert {:ok, demo} = Demo.start()

    Demo.command(demo, "wait")

    output =
      capture_io(fn ->
        assert :ok = Demo.run(demo, "events for Mira")
      end)

    assert output =~ "Recent events for Mira:"
    assert output =~ "Tobin quietly warned Mira"
  end

  test "stops a demo session and prints a cleanup summary" do
    assert {:ok, demo} = Demo.start()

    output =
      capture_io(fn ->
        assert :ok = Demo.stop(demo)
      end)

    assert output =~ "Demo cleaned up."
    assert output =~ "Stopped entities:"
    assert output =~ "Missing entities:"
    assert output =~ "Status: cleaned_up"

    refute Procession.EntitySupervisor.exists?("player_main")
  end

  test "rejects invalid demo sessions during cleanup" do
    assert Demo.stop(%{}) == {:error, :invalid_demo_session}
  end
end
