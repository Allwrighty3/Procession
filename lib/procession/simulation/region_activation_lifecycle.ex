defmodule Procession.Simulation.RegionActivationLifecycle do
  use GenServer

  @moduledoc """
  Transactional process lifecycle for multi-resolution regions.

  Exact entity and mind checkpoints exist only during deactivation rollback. Successful
  dormant storage retains individual state and mind snapshots only for bounded identity
  anchors. Unanchored developmental minds are represented by a bounded population
  summary of causally distinct cohorts.
  """

  alias Procession.Entity
  alias Procession.EntitySupervisor
  alias Procession.Simulation.LiveResolutionManager
  alias Procession.Simulation.MultiResolutionRegion
  alias Procession.Simulation.PopulationMindSummary

  @name __MODULE__

  def start_link(opts \\ []) do
    state = %{
      archives: %{},
      resolution_server: Keyword.get(opts, :resolution_server, LiveResolutionManager),
      entity_supervisor: Keyword.get(opts, :entity_supervisor, EntitySupervisor)
    }

    GenServer.start_link(__MODULE__, state, name: Keyword.get(opts, :name, @name))
  end

  def deactivate(region_id, opts \\ [], server \\ @name),
    do: GenServer.call(server, {:deactivate, region_id, opts}, :infinity)

  def activate(region_id, seed, opts \\ [], server \\ @name),
    do: GenServer.call(server, {:activate, region_id, seed, opts}, :infinity)

  def archive(region_id, server \\ @name), do: GenServer.call(server, {:archive, region_id})
  def trace(server \\ @name), do: GenServer.call(server, :trace)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:deactivate, region_id, opts}, _from, state) do
    case deactivate_region(region_id, opts, state) do
      {:ok, reply, updated} -> {:reply, {:ok, reply}, updated}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:activate, region_id, seed, opts}, _from, state) do
    case activate_region(region_id, seed, opts, state) do
      {:ok, reply, updated} -> {:reply, {:ok, reply}, updated}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:archive, region_id}, _from, state),
    do: {:reply, Map.fetch(state.archives, region_id), state}

  def handle_call(:trace, _from, state) do
    trace =
      Map.new(state.archives, fn {region_id, archive} ->
        {region_id,
         %{
           identity_count: map_size(archive.snapshots),
           identities: archive.snapshots |> Map.keys() |> Enum.sort(),
           anchored_mind_count: map_size(archive.mind_snapshots),
           population_minds: PopulationMindSummary.trace(archive.population_minds),
           compressed_at_tick: archive.compressed_at_tick
         }}
      end)

    {:reply, trace, state}
  end

  defp deactivate_region(region_id, opts, state) do
    with {:ok, region} <- LiveResolutionManager.fetch(region_id, state.resolution_server),
         :ok <- require_live(region),
         :ok <- require_entities_present(region, state.entity_supervisor),
         {:ok, candidate} <- build_compressed_candidate(region, opts),
         {:ok, entity_snapshots} <- capture_entity_snapshots(Map.keys(region.entities)),
         {:ok, mind_checkpoints, mind_snapshots} <-
           capture_minds(Map.keys(region.entities), state.entity_supervisor, opts),
         {:ok, _trace} <- LiveResolutionManager.put(candidate, state.resolution_server) do
      ids = region.entities |> Map.keys() |> Enum.sort()

      case stop_all(ids, state.entity_supervisor) do
        {:ok, stopped} ->
          anchored_ids = Map.get(candidate.summary, :identity_anchors, [])
          unanchored_ids = ids -- anchored_ids

          population_snapshots =
            mind_snapshots
            |> Map.take(unanchored_ids)
            |> Map.values()

          archive = %{
            snapshots: Map.take(entity_snapshots, anchored_ids),
            mind_snapshots: Map.take(mind_snapshots, anchored_ids),
            population_minds:
              PopulationMindSummary.capture(population_snapshots, length(unanchored_ids), opts),
            compressed_at_tick: region.tick,
            stopped_entity_ids: stopped
          }

          {:ok, MultiResolutionRegion.trace(candidate), put_in(state.archives[region_id], archive)}

        {:error, reason, stopped} ->
          rollback_stopped(stopped, entity_snapshots, mind_checkpoints, state.entity_supervisor)
          LiveResolutionManager.put(region, state.resolution_server)
          {:error, {:deactivation_failed, reason}}
      end
    end
  end

  defp activate_region(region_id, seed, opts, state) do
    with {:ok, region} <- LiveResolutionManager.fetch(region_id, state.resolution_server),
         :ok <- require_compressed(region),
         {:ok, archive} <- fetch_archive(state, region_id),
         {:ok, refined} <- refine_candidate(region, seed, opts),
         :ok <- require_no_collisions(refined, state.entity_supervisor),
         {:ok, started} <- start_all(refined, archive, seed, opts, state.entity_supervisor) do
      case LiveResolutionManager.put(refined, state.resolution_server) do
        {:ok, _trace} ->
          updated = update_in(state.archives, &Map.delete(&1, region_id))
          {:ok, MultiResolutionRegion.trace(refined), updated}

        error ->
          stop_started(started, state.entity_supervisor)
          {:error, {:activation_commit_failed, error}}
      end
    else
      {:error, {:start_failed, reason, started}} ->
        stop_started(started, state.entity_supervisor)
        {:error, {:activation_failed, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_archive(state, region_id) do
    case Map.fetch(state.archives, region_id) do
      {:ok, archive} -> {:ok, archive}
      :error -> {:error, :activation_archive_not_found}
    end
  end

  defp require_live(%MultiResolutionRegion{resolution: :live}), do: :ok
  defp require_live(_region), do: {:error, :region_not_live}

  defp require_compressed(%MultiResolutionRegion{resolution: resolution})
       when resolution in [:coarse, :inert],
       do: :ok

  defp require_compressed(_region), do: {:error, :region_not_compressed}

  defp require_entities_present(region, supervisor) do
    missing =
      region.entities
      |> Map.keys()
      |> Enum.reject(&supervisor.exists?/1)
      |> Enum.sort()

    if missing == [], do: :ok, else: {:error, {:entities_not_live, missing}}
  end

  defp build_compressed_candidate(region, opts) do
    try do
      candidate = LiveResolutionManager.compress_region(region, opts)

      candidate =
        if Keyword.get(opts, :inert, true),
          do: MultiResolutionRegion.make_inert(candidate),
          else: candidate

      {:ok, candidate}
    rescue
      error in ArgumentError -> {:error, Exception.message(error)}
    end
  end

  defp capture_entity_snapshots(ids) do
    ids
    |> Enum.sort()
    |> Enum.reduce_while(%{}, fn id, acc ->
      try do
        {:cont, Map.put(acc, id, Entity.get_state(id))}
      catch
        :exit, reason -> {:halt, {:error, {:snapshot_failed, id, reason}}}
      end
    end)
    |> case do
      {:error, _reason} = error -> error
      snapshots -> {:ok, snapshots}
    end
  end

  defp capture_minds(ids, supervisor, opts) do
    ids
    |> Enum.sort()
    |> Enum.filter(&supervisor.sensorimotor_enabled?/1)
    |> Enum.reduce_while({%{}, %{}}, fn id, {checkpoints, snapshots} ->
      with {:ok, checkpoint} <- supervisor.sensorimotor_checkpoint(id),
           {:ok, snapshot} <- supervisor.sensorimotor_snapshot(id, opts) do
        {:cont, {Map.put(checkpoints, id, checkpoint), Map.put(snapshots, id, snapshot)}}
      else
        {:error, reason} -> {:halt, {:error, {:mind_snapshot_failed, id, reason}}}
      end
    end)
    |> case do
      {:error, _reason} = error -> error
      {checkpoints, snapshots} -> {:ok, checkpoints, snapshots}
    end
  end

  defp stop_all(ids, supervisor) do
    Enum.reduce_while(ids, {:ok, []}, fn id, {:ok, stopped} ->
      case supervisor.stop_entity(id) do
        :ok -> {:cont, {:ok, [id | stopped]}}
        {:error, reason} -> {:halt, {:error, {id, reason}, Enum.reverse(stopped)}}
      end
    end)
    |> case do
      {:ok, stopped} -> {:ok, Enum.reverse(stopped)}
      other -> other
    end
  end

  defp rollback_stopped(stopped, snapshots, mind_checkpoints, supervisor) do
    Enum.each(stopped, fn id ->
      attrs =
        snapshots
        |> Map.fetch!(id)
        |> entity_attrs()
        |> maybe_attach_loop(Map.get(mind_checkpoints, id))

      supervisor.start_entity(id, attrs)
    end)
  end

  defp refine_candidate(region, seed, opts) do
    try do
      {:ok, LiveResolutionManager.refine_region(region, seed, opts)}
    rescue
      error in ArgumentError -> {:error, Exception.message(error)}
    end
  end

  defp require_no_collisions(refined, supervisor) do
    collisions =
      refined.entities
      |> Map.keys()
      |> Enum.filter(&supervisor.exists?/1)
      |> Enum.sort()

    if collisions == [], do: :ok, else: {:error, {:entity_id_collisions, collisions}}
  end

  defp start_all(refined, archive, seed, opts, supervisor) do
    refined.entities
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce_while({:ok, [], 0}, fn {id, physical}, {:ok, started, ordinal} ->
      anchored? = Map.has_key?(archive.snapshots, id)
      next_ordinal = if anchored?, do: ordinal, else: ordinal + 1

      attrs =
        case Map.fetch(archive.snapshots, id) do
          {:ok, snapshot} ->
            snapshot
            |> entity_attrs()
            |> merge_physical_attrs(physical, refined.id)
            |> maybe_attach_snapshot(Map.get(archive.mind_snapshots, id))

          :error ->
            mind_snapshot = population_snapshot(archive.population_minds, seed, next_ordinal, opts)

            physical
            |> reconstructed_attrs(refined.id)
            |> maybe_attach_snapshot(mind_snapshot)
        end

      case supervisor.start_entity(id, attrs) do
        {:ok, _pid} -> {:cont, {:ok, [id | started], next_ordinal}}
        {:error, reason} ->
          {:halt, {:error, {:start_failed, {id, reason}, Enum.reverse(started)}}}
      end
    end)
    |> case do
      {:ok, started, _ordinal} -> {:ok, Enum.reverse(started)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp population_snapshot(summary, seed, ordinal, opts) do
    case PopulationMindSummary.instantiate(summary, seed, ordinal, opts) do
      {:ok, snapshot} -> snapshot
      :none -> nil
      {:error, reason} -> raise ArgumentError, "population mind refinement failed: #{inspect(reason)}"
    end
  end

  defp stop_started(ids, supervisor), do: Enum.each(ids, &supervisor.stop_entity/1)

  defp entity_attrs(%Entity{} = snapshot),
    do: snapshot |> Map.from_struct() |> Map.delete(:id)

  defp merge_physical_attrs(attrs, physical, region_id) do
    metadata = attrs |> Map.get(:metadata, %{}) |> Map.put(:physical_state, physical)
    attrs |> Map.put(:location, region_id) |> Map.put(:metadata, metadata)
  end

  defp reconstructed_attrs(physical, region_id) do
    %{
      name: to_string(physical.id),
      type: :npc,
      location: region_id,
      status: :idle,
      traits: %{},
      metadata: %{physical_state: physical}
    }
  end

  defp maybe_attach_loop(attrs, nil), do: attrs
  defp maybe_attach_loop(attrs, loop), do: Map.put(attrs, :sensorimotor, [loop: loop])
  defp maybe_attach_snapshot(attrs, nil), do: attrs
  defp maybe_attach_snapshot(attrs, snapshot), do: Map.put(attrs, :sensorimotor, [snapshot: snapshot])
end
