defmodule Procession.Simulation.InternalFields do
  @moduledoc """
  Public access layer for live internal field processes.

  This module starts, locates, and routes calls to one internal field process
  per active individual. It does not own field rules; those stay in
  Procession.Simulation.InternalField.
  """

  alias Procession.Simulation.InternalFieldProcess

  @registry Procession.Simulation.InternalFieldRegistry
  @supervisor Procession.Simulation.InternalFieldSupervisor

  def ensure_started(entity_id) when is_binary(entity_id) do
    case Registry.lookup(@registry, entity_id) do
      [{pid, _metadata}] when is_pid(pid) ->
        {:ok, pid}

      [] ->
        start_field(entity_id)
    end
  end

  def apply_presentation(entity_id, presentation, context \\ [])
      when is_binary(entity_id) and is_map(presentation) and is_list(context) do
    call_with_ensured_field(entity_id, fn ->
      entity_id
      |> via_tuple()
      |> InternalFieldProcess.apply_presentation(presentation, context)
    end)
  end

  def snapshot(entity_id) when is_binary(entity_id) do
    call_with_ensured_field(entity_id, fn ->
      entity_id
      |> via_tuple()
      |> InternalFieldProcess.snapshot()
    end)
  end

  defp call_with_ensured_field(entity_id, fun) when is_function(fun, 0) do
    with {:ok, _pid} <- ensure_started(entity_id) do
      safe_call(fun)
    end
    |> case do
      {:ok, result} ->
        result

      {:retry, _reason} ->
        with {:ok, _pid} <- ensure_started(entity_id) do
          safe_call(fun)
        end
        |> case do
          {:ok, result} -> result
          {:retry, reason} -> exit(reason)
        end

      error ->
        error
    end
  end

  defp safe_call(fun) do
    {:ok, fun.()}
  catch
    :exit, reason ->
      {:retry, reason}
  end

  defp start_field(entity_id) do
    child_spec = %{
      id: {:internal_field, entity_id},
      start:
        {InternalFieldProcess, :start_link,
         [
           [
             entity_id: entity_id,
             name: via_tuple(entity_id)
           ]
         ]},
      restart: :temporary,
      type: :worker
    }

    case DynamicSupervisor.start_child(@supervisor, child_spec) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, {:shutdown, {:failed_to_start_child, _child_id, {:already_started, pid}}}} ->
        {:ok, pid}

      error ->
        error
    end
  end

  defp via_tuple(entity_id) do
    {:via, Registry, {@registry, entity_id}}
  end
end
