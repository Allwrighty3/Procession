defmodule Procession.Dialogue.Context do
  @moduledoc """
  Builds plain-data dialogue context from authoritative simulation state.

  This module does not call AI, build prompts, mutate entities, or decide game state.
  It gathers inspectable facts that later prompt builders or dialogue boundaries can consume.
  """

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.GameSession

  @doc """
  Builds grounded dialogue context for a target entity inside a live game session.

  The returned context is plain data. It is safe to inspect in tests and safe to pass
  to later prompt-building code.
  """
  def from_session(session, target_id, message, opts \\ [])

  def from_session(session, target_id, message, opts)
      when is_pid(session) and is_binary(target_id) and is_binary(message) and is_list(opts) do
    with true <- GameSession.owns_entity?(session, target_id),
         true <- EntitySupervisor.exists?(target_id),
         {:ok, player_id} <- session_player(session),
         {:ok, target_state} <- get_entity_state(target_id),
         {:ok, speaker_state} <- get_entity_state(player_id),
         {:ok, location_context} <- current_location_context(session),
         {:ok, active_entity_context} <- active_entities_context(session),
         {:ok, target_memories} <- target_memories(target_id, opts) do
      {:ok,
       %{
         target: entity_facts(target_state),
         speaker: speaker_facts(speaker_state),
         message: message,
         location: location_context,
         active_entities: active_entity_context,
         target_memories: target_memories
       }}
    else
      false -> {:error, :entity_not_in_session}
      {:error, reason} -> {:error, reason}
    end
  end

  def from_session(_session, _target_id, _message, _opts) do
    {:error, :invalid_dialogue_context}
  end

  defp session_player(session) do
    case GameSession.player(session) do
      nil -> {:error, :player_not_found}
      player_id when is_binary(player_id) -> {:ok, player_id}
    end
  end

  defp current_location_context(session) do
    with {:ok, location_id} <- GameSession.player_location(session),
         true <- EntitySupervisor.exists?(location_id),
         {:ok, location_state} <- get_entity_state(location_id) do
      {:ok,
       %{
         id: location_state.id,
         name: location_state.name,
         type: location_state.type,
         description: Map.get(location_state.metadata, :description),
         exits: Map.get(location_state.metadata, :exits, [])
       }}
    else
      false -> {:error, :location_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp active_entities_context(session) do
    session
    |> GameSession.active_entities()
    |> Enum.reduce({:ok, []}, fn
      _entity_id, {:error, reason} ->
        {:error, reason}

      entity_id, {:ok, entities} ->
        if EntitySupervisor.exists?(entity_id) do
          case get_entity_state(entity_id) do
            {:ok, entity_state} -> {:ok, [entity_facts(entity_state) | entities]}
            {:error, reason} -> {:error, reason}
          end
        else
          {:ok, entities}
        end
    end)
    |> case do
      {:ok, entities} -> {:ok, Enum.reverse(entities)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp target_memories(target_id, opts) do
    query = Keyword.get(opts, :memory_query)

    memories =
      cond do
        is_binary(query) ->
          Entity.recall(target_id, query)

        true ->
          Entity.recall_all(target_id)
      end

    {:ok, memories}
  end

  defp get_entity_state(entity_id) do
    try do
      {:ok, Entity.get_state(entity_id)}
    catch
      :exit, _reason -> {:error, :entity_not_found}
    end
  end

  defp entity_facts(state) do
    %{
      id: state.id,
      name: state.name,
      type: state.type,
      status: state.status,
      location: state.location,
      traits: state.traits
    }
  end

  defp speaker_facts(state) do
    %{
      id: state.id,
      name: state.name,
      type: state.type
    }
  end
end
