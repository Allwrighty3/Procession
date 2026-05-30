defmodule Procession.Command.DisplayTest do
  use ExUnit.Case, async: false

  alias Procession.Command
  alias Procession.Command.Display
  alias Procession.GameSession

  setup do
    on_exit(fn ->
      Enum.each(Procession.EntitySupervisor.list_entities(), fn {id, _pid} ->
        Procession.EntitySupervisor.stop_entity(id)
      end)
    end)
  end

  test "formats look command output as readable text" do
    assert {:ok, demo} = GameSession.start_demo()
    result = Command.run(demo.session, "look")

    text = Display.format(result)

    assert text =~ "Old Road Crossroads"
    assert text =~ "Exits:"
    assert text =~ "Local entities:"
    assert text =~ "npc_tobin"
  end

  test "formats ask about command output as readable text" do
    assert {:ok, demo} = GameSession.start_demo()
    result = Command.run(demo.session, "ask Tobin about road")

    text = Display.format(result)

    assert text =~ "Tobin remembers about road:"
    assert text =~ "The old road has been quieter"
  end

  test "formats wait command output as readable text" do
    assert {:ok, demo} = GameSession.start_demo()
    result = Command.run(demo.session, "wait")

    text = Display.format(result)

    assert text =~ "Time passes."
    assert text =~ "Entities ticked:"
    assert text =~ "npc_tobin sent npc_mira"
  end

  test "formats travel command output as readable text" do
    assert {:ok, demo} = GameSession.start_demo()
    result = Command.run(demo.session, "go to Briar Village")

    text = Display.format(result)

    assert text =~ "You travel to Briar Village."
    assert text =~ "From: loc_crossroads"
    assert text =~ "To: loc_briar_village"
    assert text =~ "Via: village road"
  end

  test "formats travel with canonical destination name when available" do
    text =
      Display.format(
        {:ok,
         %{
           command: :travel_to,
           destination: "briar village",
           destination_name: "Briar Village",
           result: %{
             from: "loc_crossroads",
             to: "loc_briar_village",
             via: "east"
           }
         }}
      )

    assert text =~ "You travel to Briar Village."
    assert text =~ "From: loc_crossroads"
    assert text =~ "To: loc_briar_village"
    assert text =~ "Via: east"
  end

  test "formats travel with typed destination when canonical destination name is unavailable" do
    text =
      Display.format(
        {:ok,
         %{
           command: :travel_to,
           destination: "briar village",
           result: %{
             from: "loc_crossroads",
             to: "loc_briar_village",
             via: "east"
           }
         }}
      )

    assert text =~ "You travel to briar village."
  end

  test "formats unknown command errors readably" do
    assert Display.format({:error, :unknown_command}) ==
             "Error: I don't know what you mean. Try `help`."
  end

  test "formats invalid command errors readably" do
    assert Display.format({:error, :invalid_command}) ==
             "Error: That command is not valid. Try `help`."
  end

  test "formats missing command parts readably" do
    assert Display.format({:error, :missing_target}) ==
             "Error: Missing target. Try: look at Tobin."

    assert Display.format({:error, :missing_topic}) ==
             "Error: Missing topic. Try: ask Tobin about road."

    assert Display.format({:error, :missing_message}) ==
             "Error: Missing message. Try: talk to Tobin: Hello."
  end

  test "formats target and travel errors readably" do
    assert Display.format({:error, :entity_not_found}) ==
             "Error: I couldn't find that target."

    assert Display.format({:error, :unknown_destination}) ==
             "You cannot travel there."

    assert Display.format({:error, :destination_unreachable}) ==
             "You cannot reach that place from here."
  end

  test "formats ambiguous entity errors readably" do
    assert Display.format({:error, {:ambiguous_entity, ["npc_a", "npc_b"]}}) ==
             "Error: That name is ambiguous. Matching IDs: npc_a, npc_b"
  end

  test "falls back for unrecognized errors" do
    assert Display.format({:error, :weird_new_error}) ==
             "Error: :weird_new_error"
  end

  test "formats talk to command output as readable text" do
    assert {:ok, demo} = Procession.GameSession.start_demo()
    result = Procession.Command.run(demo.session, "talk to Tobin: Hello there.")

    text = Procession.Command.Display.format(result)

    assert text =~ "Tobin says:"
  end

  test "formats talk responses with canonical entity name when available" do
    text =
      Display.format(
        {:ok,
         %{
           command: :talk_to,
           target: "tobin",
           entity_name: "Tobin",
           result: "Hello."
         }}
      )

    assert text == "Tobin says: Hello."
  end

  test "formats talk responses with target when canonical entity name is unavailable" do
    text =
      Display.format(
        {:ok,
         %{
           command: :talk_to,
           target: "tobin",
           result: "Hello."
         }}
      )

    assert text == "tobin says: Hello."
  end

  test "formats unsupported talk target errors" do
    assert Display.format({:error, :entity_not_talkable}) ==
             "You cannot talk to that."
  end

  test "formats unsupported ask target errors" do
    assert Display.format({:error, :entity_not_askable}) ==
             "You cannot ask that about anything."
  end

  test "formats unreachable travel errors" do
    assert Display.format({:error, :destination_unreachable}) ==
             "You cannot reach that place from here."
  end
end
