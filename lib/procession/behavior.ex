defmodule Procession.Behavior do
  @moduledoc """
  Validates and eventually executes safe entity behavior metadata.

  Behavior metadata is data, not executable code. This module defines the small
  allowed behavior vocabulary that generated entities may carry.
  """

  @supported_triggers [:world_tick]
  @supported_actions [:send_message]

  def validate(behavior) when is_map(behavior) do
    with :ok <- validate_trigger(behavior),
         :ok <- validate_action(behavior),
         :ok <- validate_required_fields(behavior) do
      :ok
    end
  end

  def validate(_behavior), do: {:error, :invalid_behavior}

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
end
