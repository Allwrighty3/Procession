defmodule Procession.Command do
  @moduledoc """
  Deterministic text command boundary for player commands.

  This module translates simple command strings into existing session-aware
  gameplay APIs. It does not own gameplay logic.
  """

  alias Procession.GameSession
  alias Procession.Entity
  alias Procession.EntitySupervisor

  @doc """
  Runs a deterministic player command against a game session.

  Command parsing is intentionally small and local. AI command interpretation,
  fuzzy matching, aliases, and CLI behavior are deferred.
  """
  def run(_session, command_text) when not is_binary(command_text) do
    {:error, :invalid_command}
  end

  def run(session, command_text) do
    command_text
    |> String.trim()
    |> parse()
    |> execute(session)
  end

  defp parse(""), do: {:error, :invalid_command}
  defp parse("look"), do: {:ok, :look}
  defp parse("look at"), do: {:error, :missing_target}

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

  defp parse(_command), do: {:error, :unknown_command}

  defp execute({:ok, :look}, session) do
    case GameSession.perform(session, :look) do
      {:ok, result} ->
        {:ok, %{command: :look, result: result}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute({:ok, {:look_at, target}}, session) do
    with {:ok, entity_id} <- resolve_entity(session, target),
         {:ok, result} <- GameSession.perform(session, :look, entity_id: entity_id) do
      {:ok, %{command: :look_at, target: target, entity_id: entity_id, result: result}}
    end
  end

  defp execute({:ok, {:ask_about, target, topic}}, session) do
    with {:ok, entity_id} <- resolve_entity(session, target),
         {:ok, result} <-
           GameSession.perform(session, :ask_about, entity_id: entity_id, topic: topic) do
      {:ok,
       %{command: :ask_about, target: target, entity_id: entity_id, topic: topic, result: result}}
    end
  end

  defp execute({:error, reason}, _session), do: {:error, reason}

  defp resolve_entity(session, target) do
    owned_entities = GameSession.active_entities(session)

    cond do
      target in owned_entities ->
        {:ok, target}

      true ->
        resolve_entity_by_name(owned_entities, target)
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
        entity.name == target_name
      catch
        :exit, _reason ->
          false
      end
    else
      false
    end
  end
end
