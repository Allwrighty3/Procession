defmodule Procession.Behavior do
  @moduledoc """
  Validates and eventually executes safe entity behavior metadata.

  Behavior metadata is data, not executable code. This module defines the small
  allowed behavior vocabulary that generated entities may carry.
  """

  @supported_triggers [:world_tick]
  @supported_actions [:send_message, :change_status]

  def validate(behavior) when is_map(behavior) do
    with :ok <- validate_trigger(behavior),
         :ok <- validate_action(behavior),
         :ok <- validate_required_fields(behavior) do
      :ok
    end
  end

  def validate(_behavior), do: {:error, :invalid_behavior}

  def execute(entity_state, behavior) do
    case validate(behavior) do
      :ok ->
        do_execute(entity_state, behavior)

      {:error, reason} ->
        {%{
           status: :error,
           action: Map.get(behavior, :action),
           from: Map.get(entity_state, :id),
           reason: reason
         }, entity_state}
    end
  end

  defp do_execute(entity_state, %{action: :send_message} = behavior) do
    message = %{
      type: Map.get(behavior, :type, :message),
      content: behavior.content,
      importance: Map.get(behavior, :importance, 1),
      tags: Map.get(behavior, :tags, []),
      metadata:
        Map.merge(Map.get(behavior, :metadata, %{}), %{
          source: :entity_tick
        })
    }

    action_result =
      case Procession.Entity.send_to(entity_state.id, behavior.to, message) do
        :ok ->
          %{
            status: :ok,
            action: :send_message,
            from: entity_state.id,
            to: behavior.to,
            type: message.type,
            content: message.content
          }

        {:error, reason} ->
          %{
            status: :error,
            action: :send_message,
            from: entity_state.id,
            to: behavior.to,
            reason: reason
          }
      end

    {action_result, entity_state}
  end

  defp do_execute(entity_state, %{action: :change_status} = behavior) do
    updated_state = %{entity_state | status: behavior.status}

    action_result = %{
      status: :ok,
      action: :change_status,
      entity_id: entity_state.id,
      old_status: entity_state.status,
      new_status: behavior.status
    }

    {action_result, updated_state}
  end

  defp validate_trigger(behavior) do
    trigger = Map.get(behavior, :trigger)

    cond do
      is_nil(trigger) ->
        {:error, {:missing_behavior_field, :trigger}}

      trigger in @supported_triggers ->
        :ok

      true ->
        {:error, {:unsupported_behavior_trigger, trigger}}
    end
  end

  defp validate_action(behavior) do
    action = Map.get(behavior, :action)

    cond do
      is_nil(action) ->
        {:error, {:missing_behavior_field, :action}}

      action in @supported_actions ->
        :ok

      true ->
        {:error, {:unsupported_behavior_action, action}}
    end
  end

  defp validate_required_fields(%{action: :send_message} = behavior) do
    with :ok <- require_non_empty_binary(behavior, :to),
         :ok <- require_non_empty_binary(behavior, :content) do
      :ok
    end
  end

  defp validate_required_fields(%{action: :change_status} = behavior) do
    require_valid_status(behavior)
  end

  defp validate_required_fields(_behavior), do: :ok

  defp require_non_empty_binary(behavior, field) do
    case Map.fetch(behavior, field) do
      :error ->
        {:error, {:missing_behavior_field, field}}

      {:ok, value} when is_binary(value) and value != "" ->
        :ok

      {:ok, _value} ->
        {:error, {:invalid_behavior_field, field}}
    end
  end

  defp require_valid_status(behavior) do
    case Map.fetch(behavior, :status) do
      :error ->
        {:error, {:missing_behavior_field, :status}}

      {:ok, value} when is_atom(value) ->
        :ok

      {:ok, _value} ->
        {:error, {:invalid_behavior_field, :status}}
    end
  end
end
