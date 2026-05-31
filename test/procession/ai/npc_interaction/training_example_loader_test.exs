defmodule Procession.AI.NPCInteraction.TrainingExampleLoaderTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.TrainingExampleLoader

  test "loads default NPC interaction training examples" do
    assert {:ok, examples} = TrainingExampleLoader.load_default()

    assert length(examples) == 25

    first = hd(examples)

    assert first["id"] == "npc_identity_tobin_denies_being_mira"
    assert first["task"] == "npc_interaction"
    assert first["context"]["target"]["id"] == "npc_tobin"
    assert first["context"]["speaker"]["id"] == "player"
    assert first["expected_response"] =~ "Tobin"
    assert "identity_drift" in first["failure_tags"]
  end

  test "ignores blank lines" do
    path =
      temp_jsonl("""
      #{valid_example_json()}

      #{valid_example_json("second_example")}
      """)

    assert {:ok, examples} = TrainingExampleLoader.load(path)
    assert Enum.map(examples, & &1["id"]) == ["valid_example", "second_example"]
  end

  test "returns line number for invalid JSONL" do
    path =
      temp_jsonl("""
      #{valid_example_json()}
      not json
      """)

    assert {:error, {:invalid_jsonl_line, 2, _reason}} = TrainingExampleLoader.load(path)
  end

  test "returns line number for missing top-level fields" do
    path = temp_jsonl(~s({"id":"missing_required_fields"}))

    assert {:error, {:invalid_training_example, 1, {:missing_field, "task"}}} =
             TrainingExampleLoader.load(path)
  end

  test "returns line number for missing context fields" do
    example =
      valid_example()
      |> put_in(["context"], %{})

    path = temp_jsonl(Jason.encode!(example))

    assert {:error, {:invalid_training_example, 1, {:missing_field, "target"}}} =
             TrainingExampleLoader.load(path)
  end

  test "requires target and speaker identity fields" do
    example =
      valid_example()
      |> put_in(["context", "speaker"], %{"id" => "npc_mira", "type" => "npc"})

    path = temp_jsonl(Jason.encode!(example))

    assert {:error, {:invalid_training_example, 1, {:missing_field, "context.speaker.name"}}} =
             TrainingExampleLoader.load(path)
  end

  test "requires npc_interaction task" do
    example =
      valid_example()
      |> Map.put("task", "world_generation")

    path = temp_jsonl(Jason.encode!(example))

    assert {:error, {:invalid_training_example, 1, {:invalid_field, "task"}}} =
             TrainingExampleLoader.load(path)
  end

  defp temp_jsonl(contents) do
    path =
      Path.join(
        System.tmp_dir!(),
        "npc_interaction_training_#{System.unique_integer([:positive])}.jsonl"
      )

    File.write!(path, contents)
    path
  end

  defp valid_example_json(id \\ "valid_example") do
    valid_example()
    |> Map.put("id", id)
    |> Jason.encode!()
  end

  defp valid_example do
    %{
      "id" => "valid_example",
      "task" => "npc_interaction",
      "context" => %{
        "target" => %{
          "id" => "npc_tobin",
          "name" => "Tobin",
          "type" => "npc",
          "role" => "merchant"
        },
        "speaker" => %{
          "id" => "npc_mira",
          "name" => "Mira",
          "type" => "npc"
        },
        "message" => "Who is Mira?",
        "known_entities" => [],
        "known_locations" => [],
        "scene_entities" => [],
        "memories" => [],
        "location_context" => nil,
        "world_context" => nil
      },
      "expected_response" => "Mira is the innkeeper in Briar Village.",
      "rejected_responses" => ["I am Mira."],
      "failure_tags" => ["identity_drift"],
      "notes" => "A valid training example."
    }
  end
end
