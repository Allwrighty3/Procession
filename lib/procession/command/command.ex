defmodule Procession.Command do
  @moduledoc """
  Deterministic text command boundary for player commands.

  This module translates simple command strings into existing session-aware
  gameplay APIs. It does not own gameplay logic.
  """

  alias Procession.GameSession
  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.EntityCapabilities

  @doc """
  Runs a deterministic player command against a game session.

  Command parsing is intentionally small and local. AI command interpretation,
  fuzzy matching, aliases, and CLI behavior are deferred.
  """

  def run(session, command_text, opts \\ [])

  def run(_session, command_text, _opts) when not is_binary(command_text) do
    {:error, :invalid_command}
  end

  def run(session, command_text, opts) when is_list(opts) do
    command_text
    |> String.trim()
    |> parse()
    |> execute(session, opts)
  end

  defp parse(""), do: {:error, :invalid_command}
  defp parse("look"), do: {:ok, :look}
  defp parse("wait"), do: {:ok, :wait}
  defp parse("look at"), do: {:error, :missing_target}
  defp parse("events for"), do: {:error, :missing_target}
  defp parse("go to"), do: {:error, :missing_target}
  defp parse("travel to"), do: {:error, :missing_target}

  defp parse("go to " <> destination) do
    parse_travel_destination(destination)
  end

  defp parse("travel to " <> destination) do
    parse_travel_destination(destination)
  end

  defp parse("look at " <> target) do
    target = String.trim(target)

    if target == "" do
      {:error, :missing_target}
    else
      {:ok, {:look_at, target}}
    end
  end

  defp parse("ask " <> rest) when is_binary(rest) do
    case String.split(rest, " about", parts: 2) do
      [target, ""] ->
        target = String.trim(target)

        if target == "" do
          {:error, :missing_target}
        else
          {:error, :missing_topic}
        end

      _ ->
        parse_ask_with_topic(rest)
    end
  end

  defp parse("talk to " <> rest) do
    case String.split(rest, ":", parts: 2) do
      [target, message] ->
        target = String.trim(target)
        message = String.trim(message)

        cond do
          target == "" -> {:error, :missing_target}
          message == "" -> {:error, :missing_message}
          true -> {:ok, {:talk_to, target, message}}
        end

      _ ->
        {:error, :invalid_command}
    end
  end

  defp parse("events for " <> target) do
    target = String.trim(target)

    if target == "" do
      {:error, :missing_target}
    else
      {:ok, {:recent_events, target}}
    end
  end

  defp parse(_command), do: {:error, :unknown_command}

  defp parse_travel_destination(destination) do
    destination = String.trim(destination)

    if destination == "" do
      {:error, :missing_target}
    else
      {:ok, {:travel_to, destination}}
    end
  end

  defp parse_ask_with_topic(rest) do
    case String.split(rest, " about ", parts: 2) do
      [target, topic] ->
        target = String.trim(target)
        topic = String.trim(topic)

        cond do
          target == "" -> {:error, :missing_target}
          topic == "" -> {:error, :missing_topic}
          true -> {:ok, {:ask_about, target, topic}}
        end

      _ ->
        {:error, :invalid_command}
    end
  end

  defp execute({:ok, :look}, session, _opts) do
    session
    |> GameSession.perform(:look)
    |> enrich_look_result()
    |> wrap_result(:look)
  end

  defp execute({:ok, :wait}, session, _opts) do
    session
    |> GameSession.perform(:tick)
    |> wrap_result(:wait)
  end

  defp execute({:ok, {:look_at, target}}, session, _opts) do
    with {:ok, entity_id} <- resolve_entity(session, target) do
      session
      |> GameSession.perform(:look, entity_id: entity_id)
      |> wrap_result(:look_at, %{
        target: target,
        entity_id: entity_id,
        entity_name: entity_display_name(entity_id)
      })
    end
  end

  defp execute({:ok, {:ask_about, target, topic}}, session, _opts) do
    with {:ok, entity_id} <- resolve_entity(session, target) do
      session
      |> GameSession.perform(:ask_about, entity_id: entity_id, topic: topic)
      |> wrap_result(:ask_about, %{
        target: target,
        entity_id: entity_id,
        entity_name: entity_display_name(entity_id),
        topic: topic
      })
    end
  end

  defp execute({:ok, {:talk_to, target, message}}, session, opts) do
    with {:ok, entity_id} <- resolve_entity(session, target) do
      dialogue_opts =
        opts
        |> Keyword.take([:adapter, :model, :timeout])

      perform_opts = [entity_id: entity_id, message: message] ++ dialogue_opts

      session
      |> GameSession.perform(:talk_to, perform_opts)
      |> wrap_result(:talk_to, %{
        target: target,
        entity_id: entity_id,
        entity_name: entity_display_name(entity_id),
        message: message
      })
    end
  end

  defp execute({:ok, {:recent_events, target}}, session, _opts) do
    with {:ok, entity_id} <- resolve_entity(session, target) do
      session
      |> GameSession.perform(:recent_events, entity_id: entity_id)
      |> wrap_result(:recent_events, %{
        target: target,
        entity_id: entity_id,
        entity_name: entity_display_name(entity_id)
      })
    end
  end

  defp execute({:ok, {:travel_to, destination}}, session, _opts) do
    with {:ok, destination_id} <- resolve_location(session, destination) do
      session
      |> GameSession.perform(:travel, destination_id: destination_id)
      |> wrap_result(:travel_to, %{
        destination: destination,
        destination_id: destination_id,
        destination_name: entity_display_name(destination_id)
      })
    end
  end

  defp execute({:error, reason}, _session, _opts), do: {:error, reason}

  defp resolve_entity(session, target) do
    owned_entities = GameSession.active_entities(session)

    cond do
      target in owned_entities ->
        {:ok, target}

      true ->
        resolve_entity_by_name(owned_entities, target)
    end
  end

  defp resolve_location(session, destination) do
    owned_entities = GameSession.active_entities(session)

    cond do
      destination in owned_entities and location?(destination) ->
        {:ok, destination}

      destination in owned_entities ->
        {:error, :unknown_destination}

      true ->
        resolve_location_by_name(owned_entities, destination)
    end
  end

  defp resolve_location_by_name(entity_ids, destination_name) do
    matches =
      entity_ids
      |> Enum.filter(fn entity_id ->
        location_name_matches?(entity_id, destination_name)
      end)

    case matches do
      [] -> {:error, :entity_not_found}
      [entity_id] -> {:ok, entity_id}
      matches -> {:error, {:ambiguous_entity, matches}}
    end
  end

  defp location_name_matches?(entity_id, destination_name) do
    if EntitySupervisor.exists?(entity_id) do
      try do
        entity = Entity.get_state(entity_id)
        EntityCapabilities.location?(entity) and names_match?(entity.name, destination_name)
      catch
        :exit, _reason ->
          false
      end
    else
      false
    end
  end

  defp location?(entity_id) do
    if EntitySupervisor.exists?(entity_id) do
      try do
        entity = Entity.get_state(entity_id)
        EntityCapabilities.location?(entity)
      catch
        :exit, _reason ->
          false
      end
    else
      false
    end
  end

  defp resolve_entity_by_name(entity_ids, target_name) do
    matches =
      entity_ids
      |> Enum.filter(fn entity_id ->
        entity_name_matches?(entity_id, target_name)
      end)

    case matches do
      [] -> {:error, :entity_not_found}
      [entity_id] -> {:ok, entity_id}
      matches -> {:error, {:ambiguous_entity, matches}}
    end
  end

  defp entity_name_matches?(entity_id, target_name) do
    if EntitySupervisor.exists?(entity_id) do
      try do
        entity = Entity.get_state(entity_id)
        names_match?(entity.name, target_name)
      catch
        :exit, _reason ->
          false
      end
    else
      false
    end
  end

  defp entity_display_name(entity_id) do
    if EntitySupervisor.exists?(entity_id) do
      try do
        entity = Entity.get_state(entity_id)
        Map.get(entity, :name, entity_id)
      catch
        :exit, _reason ->
          entity_id
      end
    else
      entity_id
    end
  end

  defp names_match?(name, input) when is_binary(name) and is_binary(input) do
    String.downcase(name) == String.downcase(input)
  end

  defp names_match?(_name, _input), do: false

  defp wrap_result({:ok, result}, command) do
    {:ok, %{command: command, result: result}}
  end

  defp wrap_result({:error, reason}, _command) do
    {:error, reason}
  end

  defp wrap_result({:ok, result}, command, metadata) do
    {:ok, Map.merge(%{command: command, result: result}, metadata)}
  end

  defp wrap_result({:error, reason}, _command, _metadata) do
    {:error, reason}
  end

  defp enrich_look_result({:ok, result}) do
    local_entity_names =
      result
      |> Map.get(:local_entities, [])
      |> Enum.map(&entity_display_name/1)

    {:ok, Map.put(result, :local_entity_names, local_entity_names)}
  end

  defp enrich_look_result(error), do: error
end
