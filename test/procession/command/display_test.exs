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
    refute text =~ "npc_tobin"
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

    assert text =~ "You travel to Briar Village by village road."
    assert text =~ "You are now at Briar Village."
    assert text =~ "Previous location: loc_crossroads"
    refute text =~ "To: loc_briar_village"
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

    assert text =~ "You travel to Briar Village by east."
    assert text =~ "You are now at Briar Village."
    assert text =~ "Previous location: loc_crossroads"
    refute text =~ "To: loc_briar_village"
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

    assert text =~ "You travel to briar village by east."
    assert text =~ "You are now at briar village."
  end

  test "formats travel without route text when via is missing" do
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
             via: nil
           }
         }}
      )

    assert text =~ "You travel to Briar Village."
    refute text =~ "by nil"
    assert text =~ "You are now at Briar Village."
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

  test "formats grounded talk_to results like dialogue" do
    assert Display.format(
             {:ok,
              %{
                command: :grounded_talk_to,
                target: "tobin",
                entity_id: "npc_tobin",
                entity_name: "Tobin",
                grounded_context: true,
                message: "Who is Mira?",
                result: "Mira is the innkeeper in Briar Village."
              }}
           ) == ~s(Tobin says: Mira is the innkeeper in Briar Village.)
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

  test "formats local entities with readable names when available" do
    assert {:ok, demo} = GameSession.start_demo()
    result = Command.run(demo.session, "look")

    text = Display.format(result)

    assert text =~ "Local entities: Tobin"
    refute text =~ "Local entities: npc_tobin"
  end

  test "formats local entities from raw ids when readable names are unavailable" do
    text =
      Display.format(
        {:ok,
         %{
           command: :look,
           result: %{
             name: "Old Road Crossroads",
             description: "A muddy crossroads.",
             exits: [],
             local_entities: ["npc_tobin"]
           }
         }}
      )

    assert text =~ "Local entities: npc_tobin"
  end

  test "formats internal field snapshots" do
    formatted =
      Procession.Command.Display.format(
        {:ok,
         %{
           command: :internal_field,
           entity_name: "Tobin",
           result: %{
             topic_salience: %{mira: :high},
             topic_pressure_counts: %{mira: 1},
             disclosure_boundaries: %{mira: :high},
             trust_deltas: %{"player" => -1},
             private_concerns: [:player_asking_about_mira],
             presentations: [
               %{
                 source: "player",
                 kind: :question,
                 target: {:person, :mira},
                 text: "Who is Mira?"
               }
             ]
           }
         }}
      )

    assert formatted =~ "Internal field for Tobin:"
    assert formatted =~ "- topic_salience: %{mira: :high}"
    assert formatted =~ "- disclosure_boundaries: %{mira: :high}"
    assert formatted =~ "- trust_deltas: %{\"player\" => -1}"
    assert formatted =~ "- private_concerns: [:player_asking_about_mira]"
    assert formatted =~ "- presentations: 1"
    assert formatted =~ "- topic_pressure_counts: %{mira: 1}"
  end
end
