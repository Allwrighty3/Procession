defmodule Procession.CLITest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Procession.CLI

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)
  end

  test "play starts the demo, handles help, and quits cleanly" do
    output =
      capture_io("help\nquit\n", fn ->
        assert :ok = CLI.play()
      end)

    assert output =~ "Procession local demo started."
    assert output =~ "Commands:"
    assert output =~ "look"
    assert output =~ "quit"
    assert output =~ "Demo cleaned up."
    assert output =~ "Status: cleaned_up"
  end

  test "play handles CLI control commands case-insensitively" do
    output =
      capture_io("HELP\nQUIT\n", fn ->
        assert :ok = CLI.play()
      end)

    assert output =~ "Commands:"
    assert output =~ "Demo cleaned up."
    assert output =~ "Status: cleaned_up"
  end

  test "play does not normalize game command text" do
    output =
      capture_io("LOOK\nquit\n", fn ->
        assert :ok = CLI.play()
      end)

    assert output =~ "Error: I don't know what you mean. Try `help`."
    assert output =~ "Demo cleaned up."
  end

  test "play sends commands through the command/display pipeline" do
    output =
      capture_io("look\nquit\n", fn ->
        assert :ok = CLI.play()
      end)

    assert output =~ "Old Road Crossroads"
    assert output =~ "Exits:"
    assert output =~ "Local entities:"
    assert output =~ "Demo cleaned up."
  end

  test "play handles invalid commands without crashing" do
    output =
      capture_io("dance majestically\nquit\n", fn ->
        assert :ok = CLI.play()
      end)

    assert output =~ "Error: I don't know what you mean. Try `help`."
    assert output =~ "Demo cleaned up."
  end
end
