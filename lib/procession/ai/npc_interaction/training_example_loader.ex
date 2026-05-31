defmodule Procession.AI.NPCInteraction.TrainingExampleLoader do
  @moduledoc """
  Loads NPC interaction training examples from JSONL files.

  Training examples are inert data. Loading them does not call AI, mutate
  simulation state, create entity memory, create behavior metadata, or affect
  active scopes.
  """

  @default_path "priv/training/npc_interaction_examples.jsonl"

  @required_top_level_fields [
    "id",
    "task",
    "context",
    "expected_response",
    "rejected_responses",
    "failure_tags",
    "notes"
  ]

  @required_context_fields [
    "target",
    "speaker",
    "message",
    "known_entities",
    "known_locations",
    "scene_entities",
    "memories",
    "location_context",
    "world_context"
  ]

  @required_entity_fields ["id", "name", "type"]

  @type training_example :: map()
  @type load_result :: {:ok, [training_example()]} | {:error, term()}

  @doc """
  Loads the default NPC interaction training example file.
  """
  @spec load_default() :: load_result()
  def load_default do
    load(@default_path)
  end

  @doc """
  Loads training examples from a JSONL file.

  Blank lines are ignored.
  """
  @spec load(Path.t()) :: load_result()
  def load(path) when is_binary(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, numbered_examples} <- decode_lines(contents),
         :ok <- validate_examples(numbered_examples) do
      examples =
        Enum.map(numbered_examples, fn {_line_number, example} ->
          example
        end)

      {:ok, examples}
    end
  end

  def load(_path), do: {:error, :invalid_training_example_path}

  defp decode_lines(contents) do
    contents
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reject(fn {line, _line_number} -> String.trim(line) == "" end)
    |> Enum.reduce_while({:ok, []}, fn {line, line_number}, {:ok, examples} ->
      case Jason.decode(line) do
        {:ok, decoded} ->
          {:cont, {:ok, [{line_number, decoded} | examples]}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_jsonl_line, line_number, reason}}}
      end
    end)
    |> case do
      {:ok, examples} -> {:ok, Enum.reverse(examples)}
      error -> error
    end
  end

  defp validate_examples(examples) do
    Enum.reduce_while(examples, :ok, fn {line_number, example}, :ok ->
      case validate_example(example) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:invalid_training_example, line_number, reason}}}
      end
    end)
  end

  defp validate_example(example) when is_map(example) do
    with :ok <- require_fields(example, @required_top_level_fields),
         :ok <- validate_task(example),
         :ok <- validate_context(example["context"]),
         :ok <- validate_string(example["expected_response"], "expected_response"),
         :ok <- validate_string_list(example["rejected_responses"], "rejected_responses"),
         :ok <- validate_string_list(example["failure_tags"], "failure_tags"),
         :ok <- validate_string(example["notes"], "notes") do
      :ok
    end
  end

  defp validate_example(_example), do: {:error, :example_must_be_map}

  defp validate_task(%{"task" => "npc_interaction"}), do: :ok
  defp validate_task(_example), do: {:error, {:invalid_field, "task"}}

  defp validate_context(context) when is_map(context) do
    with :ok <- require_fields(context, @required_context_fields),
         :ok <- validate_entity(context["target"], "context.target"),
         :ok <- validate_entity(context["speaker"], "context.speaker"),
         :ok <- validate_string(context["message"], "context.message"),
         :ok <- validate_list(context["known_entities"], "context.known_entities"),
         :ok <- validate_list(context["known_locations"], "context.known_locations"),
         :ok <- validate_list(context["scene_entities"], "context.scene_entities"),
         :ok <- validate_list(context["memories"], "context.memories") do
      :ok
    end
  end

  defp validate_context(_context), do: {:error, {:invalid_field, "context"}}

  defp validate_entity(entity, field_name) when is_map(entity) do
    require_fields(entity, @required_entity_fields)
    |> case do
      :ok ->
        :ok

      {:error, {:missing_field, missing_field}} ->
        {:error, {:missing_field, "#{field_name}.#{missing_field}"}}
    end
  end

  defp validate_entity(_entity, field_name), do: {:error, {:invalid_field, field_name}}

  defp require_fields(map, fields) do
    Enum.find(fields, fn field -> not Map.has_key?(map, field) end)
    |> case do
      nil -> :ok
      missing_field -> {:error, {:missing_field, missing_field}}
    end
  end

  defp validate_string(value, _field_name) when is_binary(value) and value != "", do: :ok
  defp validate_string(_value, field_name), do: {:error, {:invalid_field, field_name}}

  defp validate_string_list(value, field_name) when is_list(value) do
    if Enum.all?(value, &is_binary/1) do
      :ok
    else
      {:error, {:invalid_field, field_name}}
    end
  end

  defp validate_string_list(_value, field_name), do: {:error, {:invalid_field, field_name}}

  defp validate_list(value, _field_name) when is_list(value), do: :ok
  defp validate_list(_value, field_name), do: {:error, {:invalid_field, field_name}}
end
