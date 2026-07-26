defmodule Procession.Simulation.DormantMindArchive do
  @moduledoc """
  Performs bounded compare-and-swap replacement of one anchored dormant mind snapshot.

  RegionActivationLifecycle remains the archive owner. This module uses OTP system-state
  replacement only as a narrow compatibility boundary until lifecycle exposes the same
  operation as a first-class call. The expected snapshot prevents stale decision cycles
  from overwriting a mind that migrated or changed concurrently.
  """

  alias Procession.Simulation.RegionActivationLifecycle

  def fetch(region_id, identity_id, server \\ RegionActivationLifecycle) do
    with {:ok, archive} <- RegionActivationLifecycle.archive(region_id, server),
         {:ok, snapshot} <- Map.fetch(archive.mind_snapshots, identity_id) do
      {:ok, snapshot}
    else
      :error -> {:error, :dormant_mind_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def replace(region_id, identity_id, expected, replacement, server \\ RegionActivationLifecycle) do
    caller = self()
    reference = make_ref()

    try do
      :sys.replace_state(server, fn state ->
        {result, updated} = replace_state(state, region_id, identity_id, expected, replacement)
        send(caller, {reference, result})
        updated
      end)

      receive do
        {^reference, result} -> result
      after
        5_000 -> {:error, :archive_replace_timeout}
      end
    catch
      :exit, reason -> {:error, {:archive_owner_unavailable, reason}}
    end
  end

  defp replace_state(state, region_id, identity_id, expected, replacement) do
    with {:ok, archive} <- Map.fetch(state.archives, region_id),
         {:ok, current} <- Map.fetch(archive.mind_snapshots, identity_id),
         true <- current == expected do
      updated_archive = %{archive | mind_snapshots: Map.put(archive.mind_snapshots, identity_id, replacement)}
      {:ok, put_in(state.archives[region_id], updated_archive)}
    else
      :error -> {{:error, :dormant_mind_not_found}, state}
      false -> {{:error, :stale_dormant_mind_snapshot}, state}
    end
    |> normalize_result()
  end

  defp normalize_result({:ok, state}), do: {:ok, state}
  defp normalize_result({result, state}), do: {result, state}
end
