defmodule Procession.Game do
  @moduledoc """
  Public gameplay boundary for player-facing inspection and actions.

  This module should orchestrate existing systems without owning long-lived state.
  Start with plain function calls before adding command parsing, LiveView, or
  stateful gameplay processes.
  """

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Generator

  @doc """
  Inspects a live entity and returns a player-facing summary as plain data.

  Returns `{:ok, summary}` for existing entities and
  `{:error, :entity_not_found}` for missing entities.
  """
  def look(entity_id) do
    if EntitySupervisor.exists?(entity_id) do
      try do
        state = Entity.get_state(entity_id)

        summary = %{
          id: state.id,
          name: state.name,
          type: state.type,
          location: state.location,
          status: state.status,
          traits: state.traits,
          relationships: Map.get(state.metadata, :relationships, []),
          description: Map.get(state.metadata, :description),
          memory_summary: Entity.memory_summary(entity_id)
        }

        summary =
          case state.type do
            :location ->
              Map.put(summary, :exits, Map.get(state.metadata, :exits, []))

            _ ->
              summary
          end

        {:ok, summary}
      catch
        :exit, _reason ->
          {:error, :entity_not_found}
      end
    else
      {:error, :entity_not_found}
    end
  end

  @doc """
  Returns matching memories for an entity and topic.

  This is deterministic and returns memory entries as data. It does not summarize,
  call AI, or mutate entity state.
  """

  def ask_about(entity_id, topic) when is_binary(topic) do
    if EntitySupervisor.exists?(entity_id) do
      try do
        {:ok, Entity.recall(entity_id, topic)}
      catch
        :exit, _reason ->
          {:error, :entity_not_found}
      end
    else
      {:error, :entity_not_found}
    end
  end

  def ask_about(_entity_id, _topic) do
    {:error, :invalid_topic}
  end

  @doc """
  Requests dialogue from an NPC.

  This delegates to the existing entity AI response boundary and returns generated
  dialogue as data. It does not mutate NPC state from the generated response.
  """
  def talk_to(target_id, message, opts \\ []) when is_binary(message) do
    if EntitySupervisor.exists?(target_id) do
      try do
        state = Entity.get_state(target_id)

        if talkable?(state) do
          Entity.generate_response(target_id, message, opts)
        else
          {:error, :entity_not_talkable}
        end
      catch
        :exit, _reason ->
          {:error, :entity_not_found}
      end
    else
      {:error, :entity_not_found}
    end
  end

  def talk_to(_target_id, _message, _opts) do
    {:error, :invalid_message}
  end

  @doc """
  Creates a deterministic playable world from a prompt.

  This uses the deterministic generator path, validates the generated blueprint,
  spawns live entity processes and returns a player-facing setup summary.
  """

  def new_game(prompt) do
    with {:ok, blueprint} <- Generator.generate_world(prompt),
         :ok <- Generator.validate_blueprint(blueprint),
         {:ok, spawn_summary} <- Generator.spawn_world(blueprint) do
      {:ok,
       %{
         name: blueprint.name,
         description: blueprint.description,
         prompt: blueprint.prompt,
         locations: spawn_summary.locations,
         npcs: spawn_summary.npcs,
         factions: spawn_summary.factions,
         relationships: spawn_summary.relationships,
         starter_memories: spawn_summary.starter_memories
       }}
    end
  end

  @doc """
  Coordinates one deterministic playerless world tick.

  The game layer does not own autonomous behavior. It asks live entities to tick,
  and each entity decides what to do from its own state and metadata.
  """

  def tick_world do
    entity_ids =
      EntitySupervisor.list_entities()
      |> Enum.map(fn {id, _pid} -> id end)

    tick_entities(entity_ids)
  end

  @doc """
  Ticks only the provided live entity IDs.

  This is useful for session-scoped ticking, active scopes, and future partial-world
  simulation. Missing or dead entities are reported as failed tick actions instead
  of crashing the caller.
  """
  def tick_entities(entity_ids) when is_list(entity_ids) do
    results =
      entity_ids
      |> Enum.map(&safe_tick_entity/1)

    summarize_tick_results(results)
  end

  def tick_entities(_entity_ids) do
    {:error, :invalid_entity_ids}
  end

  @doc """
  Returns recent world activity memories for an entity.

  This is a small inspection helper for seeing what happened to an entity during
  playerless world ticks.
  """
  def recent_events(entity_id) do
    if EntitySupervisor.exists?(entity_id) do
      try do
        events =
          Entity.recall_by_metadata(entity_id, :source, :world_tick) ++
            Entity.recall_by_metadata(entity_id, :source, :entity_tick)

        {:ok, events}
      catch
        :exit, _reason ->
          {:error, :entity_not_found}
      end
    else
      {:error, :entity_not_found}
    end
  end

  @doc """
  Performs a tiny deterministic player action.

  The first supported action is `:look`, which delegates to `look/1`.
  """
  def perform(:look, opts) when is_list(opts) do
    with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target) do
      look(entity_id)
    end
  end

  def perform(:ask_about, opts) when is_list(opts) do
    with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target),
         {:ok, topic} <- fetch_required_opt(opts, :topic, :missing_topic) do
      ask_about(entity_id, topic)
    end
  end

  def perform(:talk_to, opts) when is_list(opts) do
    with {:ok, entity_id} <- fetch_required_opt(opts, :entity_id, :missing_target),
         {:ok, message} <- fetch_required_opt(opts, :message, :missing_message) do
      ai_opts = Keyword.drop(opts, [:entity_id, :message])
      talk_to(entity_id, message, ai_opts)
    end
  end

  def perform(_action, _opts) do
    {:error, :invalid_action}
  end

  defp fetch_required_opt(opts, key, error_reason) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, error_reason}
    end
  end

  defp safe_tick_entity(entity_id) do
    try do
      Entity.tick(entity_id)
    catch
      :exit, reason ->
        {:ok,
         %{
           actions: [
             %{
               status: :error,
               action: :tick,
               entity_id: entity_id,
               reason: normalize_tick_exit_reason(reason)
             }
           ]
         }}
    end
  end

  defp summarize_tick_results(results) do
    actions =
      results
      |> Enum.flat_map(fn
        {:ok, %{actions: actions}} -> actions
        _ -> []
      end)

    successful_actions =
      Enum.filter(actions, fn action ->
        Map.get(action, :status) == :ok
      end)

    failed_actions =
      Enum.filter(actions, fn action ->
        Map.get(action, :status) == :error
      end)

    {:ok,
     %{
       entities_ticked: length(results),
       actions: actions,
       successful_actions: successful_actions,
       failed_actions: failed_actions
     }}
  end

  defp normalize_tick_exit_reason({{:noproc, _}, _details}), do: :entity_not_found
  defp normalize_tick_exit_reason({:noproc, _details}), do: :entity_not_found
  defp normalize_tick_exit_reason(reason), do: reason

  defp talkable?(%{type: :npc}), do: true
  defp talkable?(_state), do: false
end
