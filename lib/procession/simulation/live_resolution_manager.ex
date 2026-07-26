defmodule Procession.Simulation.LiveResolutionManager do
  use GenServer

  @moduledoc """
  OTP owner for region resolution state.

  The manager records whether a region is live, coarse, or inert and applies explicit
  transitions. It does not spawn entity processes or advance active entity minds.
  Socially referenced identities are retained as bounded causal anchors so refined
  relations do not point to nonexistent entities.
  """

  alias Procession.Simulation.MultiResolutionRegion

  @name __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: Keyword.get(opts, :name, @name))
  end

  def put(region, server \\ @name), do: GenServer.call(server, {:put, region})
  def fetch(id, server \\ @name), do: GenServer.call(server, {:fetch, id})
  def compress(id, opts \\ [], server \\ @name), do: GenServer.call(server, {:compress, id, opts})
  def make_inert(id, server \\ @name), do: GenServer.call(server, {:make_inert, id})
  def advance(id, ticks, opts \\ [], server \\ @name), do: GenServer.call(server, {:advance, id, ticks, opts})
  def refine(id, seed, opts \\ [], server \\ @name), do: GenServer.call(server, {:refine, id, seed, opts})
  def trace(server \\ @name), do: GenServer.call(server, :trace)

  @doc "Atomically transfers one dormant anchored identity between compressed regions."
  def transfer_identity(identity_id, from_region_id, to_region_id, opts \\ [], server \\ @name),
    do: GenServer.call(server, {:transfer_identity, identity_id, from_region_id, to_region_id, opts})

  @doc "Returns bounded identity-to-region commitments for compressed regions."
  def dormant_identity_locations(server \\ @name),
    do: GenServer.call(server, :dormant_identity_locations)

  @doc "Compresses a live region while retaining bounded socially referenced identities."
  def compress_region(%MultiResolutionRegion{} = region, opts \\ []) do
    limit = Keyword.get(opts, :summary_identity_limit, 16)
    coarse = MultiResolutionRegion.compress(region, opts)

    identities =
      coarse.summary.relation_anchors
      |> Enum.flat_map(fn
        {{observer_id, actor_id, _context}, _relation} -> [observer_id, actor_id]
        {_key, _relation} -> []
      end)
      |> Enum.filter(&Map.has_key?(region.entities, &1))
      |> Enum.uniq()
      |> Enum.take(limit)

    commitments =
      Map.new(identities, fn identity_id ->
        entity = Map.fetch!(region.entities, identity_id)

        {identity_id,
         Map.take(entity, [:position, :energy, :mobility, :inventory, :consumed])}
      end)

    summary =
      coarse.summary
      |> Map.put(:identity_anchors, identities)
      |> Map.put(:identity_commitments, commitments)

    %{coarse | summary: summary}
  end

  @doc "Refines a compressed region and restores bounded identity anchors."
  def refine_region(%MultiResolutionRegion{} = region, seed, opts \\ []) do
    refined = MultiResolutionRegion.refine(region, seed, opts)
    anchors = Map.get(region.summary, :identity_anchors, [])
    commitments = Map.get(region.summary, :identity_commitments, %{})
    generated = refined.entities |> Map.keys() |> Enum.sort()
    rename_pairs = Enum.zip(Enum.take(generated, length(anchors)), anchors)

    entities =
      Enum.reduce(rename_pairs, refined.entities, fn {generated_id, anchored_id}, acc ->
        entity = Map.fetch!(acc, generated_id)
        commitment = Map.get(commitments, anchored_id, %{})

        restored =
          entity
          |> Map.merge(commitment)
          |> Map.put(:id, anchored_id)

        acc
        |> Map.delete(generated_id)
        |> Map.put(anchored_id, restored)
      end)

    %{refined | entities: entities}
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:put, %MultiResolutionRegion{} = region}, _from, state) do
    commit_region(state, region)
  end

  def handle_call({:fetch, id}, _from, state) do
    case Map.fetch(state, id) do
      {:ok, region} -> {:reply, {:ok, region}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:compress, id, opts}, _from, state) do
    transition(state, id, &compress_region(&1, opts))
  end

  def handle_call({:make_inert, id}, _from, state) do
    transition(state, id, &MultiResolutionRegion.make_inert/1)
  end

  def handle_call({:advance, id, ticks, opts}, _from, state) do
    transition(state, id, &MultiResolutionRegion.coarse_run(&1, ticks, opts))
  end

  def handle_call({:refine, id, seed, opts}, _from, state) do
    transition(state, id, &refine_region(&1, seed, opts))
  end

  def handle_call({:transfer_identity, identity_id, from_id, to_id, opts}, _from, state) do
    case transfer_regions(state, identity_id, from_id, to_id, opts) do
      {:ok, source, destination} ->
        updated = state |> Map.put(from_id, source) |> Map.put(to_id, destination)

        reply = %{
          identity_id: identity_id,
          from: MultiResolutionRegion.trace(source),
          to: MultiResolutionRegion.trace(destination)
        }

        {:reply, {:ok, reply}, updated}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:trace, _from, state) do
    trace = Map.new(state, fn {id, region} -> {id, MultiResolutionRegion.trace(region)} end)
    {:reply, trace, state}
  end

  def handle_call(:dormant_identity_locations, _from, state) do
    {:reply, build_dormant_identity_locations(state), state}
  end

  defp transfer_regions(state, identity_id, from_id, to_id, _opts) do
    with :ok <- require_distinct_regions(from_id, to_id),
         {:ok, source} <- fetch_region(state, from_id),
         {:ok, destination} <- fetch_region(state, to_id),
         :ok <- require_compressed(source),
         :ok <- require_compressed(destination),
         {:ok, commitment} <- fetch_commitment(source, identity_id),
         :ok <- require_destination_free(destination, identity_id),
         {:ok, source_summary} <- remove_identity(source.summary, identity_id, commitment),
         {:ok, destination_summary} <- add_identity(destination.summary, identity_id, commitment) do
      source = %{source | summary: source_summary}
      destination = %{destination | summary: destination_summary}

      candidate_state = state |> Map.put(from_id, source) |> Map.put(to_id, destination)

      case duplicate_dormant_anchors(candidate_state) do
        [] -> {:ok, source, destination}
        conflicts -> {:error, {:identity_anchor_conflicts, conflicts}}
      end
    end
  end

  defp remove_identity(summary, identity_id, commitment) do
    population = Map.get(summary, :population, 0)

    if population <= 0 do
      {:error, :source_population_empty}
    else
      anchors = List.delete(Map.get(summary, :identity_anchors, []), identity_id)
      commitments = Map.delete(Map.get(summary, :identity_commitments, %{}), identity_id)
      relations = reject_identity_relations(Map.get(summary, :relation_anchors, []), identity_id)

      {:ok,
       summary
       |> Map.put(:identity_anchors, anchors)
       |> Map.put(:identity_commitments, commitments)
       |> Map.put(:relation_anchors, relations)
       |> adjust_population(-1, commitment)}
    end
  end

  defp add_identity(summary, identity_id, commitment) do
    anchors = Map.get(summary, :identity_anchors, [])
    commitments = Map.get(summary, :identity_commitments, %{})

    {:ok,
     summary
     |> Map.put(:identity_anchors, anchors ++ [identity_id])
     |> Map.put(:identity_commitments, Map.put(commitments, identity_id, commitment))
     |> adjust_population(1, commitment)}
  end

  defp adjust_population(summary, delta, commitment) do
    old_population = Map.get(summary, :population, 0)
    new_population = old_population + delta
    held = number(commitment, :inventory)
    consumed = number(commitment, :consumed)
    energy = number(commitment, :energy)
    mobility = number(commitment, :mobility, 1.0)

    summary
    |> Map.put(:population, new_population)
    |> Map.update(:held_stock, delta * held, &max(0.0, &1 + delta * held))
    |> Map.update(:consumed_stock, delta * consumed, &max(0.0, &1 + delta * consumed))
    |> Map.update(:total_stock, delta * (held + consumed), &max(0.0, &1 + delta * (held + consumed)))
    |> Map.put(:mean_energy, adjusted_mean(Map.get(summary, :mean_energy, 0.0), old_population, energy, delta))
    |> Map.put(:mean_mobility, adjusted_mean(Map.get(summary, :mean_mobility, 0.0), old_population, mobility, delta))
    |> Map.put(:centroid, adjusted_centroid(Map.get(summary, :centroid, {0.0, 0.0}), old_population, Map.get(commitment, :position), delta))
  end

  defp adjusted_mean(_mean, _count, _value, _delta) when false, do: 0.0
  defp adjusted_mean(mean, count, value, 1), do: (mean * count + value) / max(count + 1, 1)
  defp adjusted_mean(_mean, 1, _value, -1), do: 0.0
  defp adjusted_mean(mean, count, value, -1), do: (mean * count - value) / max(count - 1, 1)

  defp adjusted_centroid(centroid, _count, nil, _delta), do: centroid
  defp adjusted_centroid({cx, cy}, count, {x, y}, 1), do: {(cx * count + x) / max(count + 1, 1), (cy * count + y) / max(count + 1, 1)}
  defp adjusted_centroid(_centroid, 1, _position, -1), do: {0.0, 0.0}
  defp adjusted_centroid({cx, cy}, count, {x, y}, -1), do: {(cx * count - x) / max(count - 1, 1), (cy * count - y) / max(count - 1, 1)}

  defp reject_identity_relations(relations, identity_id) do
    Enum.reject(relations, fn
      {{observer_id, actor_id, _context}, _relation} ->
        observer_id == identity_id or actor_id == identity_id

      _ ->
        false
    end)
  end

  defp fetch_commitment(region, identity_id) do
    anchors = Map.get(region.summary, :identity_anchors, [])
    commitments = Map.get(region.summary, :identity_commitments, %{})

    cond do
      identity_id not in anchors -> {:error, :identity_not_anchored_in_source}
      not Map.has_key?(commitments, identity_id) -> {:error, :identity_commitment_missing}
      true -> {:ok, Map.fetch!(commitments, identity_id)}
    end
  end

  defp require_destination_free(region, identity_id) do
    if identity_id in Map.get(region.summary, :identity_anchors, []),
      do: {:error, :identity_already_in_destination},
      else: :ok
  end

  defp require_distinct_regions(id, id), do: {:error, :same_region_transfer}
  defp require_distinct_regions(_from, _to), do: :ok

  defp fetch_region(state, id) do
    case Map.fetch(state, id) do
      {:ok, region} -> {:ok, region}
      :error -> {:error, {:region_not_found, id}}
    end
  end

  defp require_compressed(%MultiResolutionRegion{resolution: resolution})
       when resolution in [:coarse, :inert],
       do: :ok

  defp require_compressed(_region), do: {:error, :region_not_compressed}

  defp transition(state, id, fun) do
    case Map.fetch(state, id) do
      {:ok, region} ->
        try do
          updated = fun.(region)
          commit_region(state, updated)
        rescue
          error in ArgumentError -> {:reply, {:error, Exception.message(error)}, state}
        end

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  defp commit_region(state, %MultiResolutionRegion{id: id} = region) do
    case identity_anchor_conflicts(state, region) do
      [] ->
        {:reply, {:ok, MultiResolutionRegion.trace(region)}, Map.put(state, id, region)}

      conflicts ->
        {:reply, {:error, {:identity_anchor_conflicts, conflicts}}, state}
    end
  end

  defp identity_anchor_conflicts(state, %MultiResolutionRegion{id: id} = region) do
    candidate = dormant_anchors(region)

    state
    |> Map.delete(id)
    |> build_dormant_identity_locations()
    |> Enum.flat_map(fn {identity_id, region_id} ->
      if identity_id in candidate, do: [{identity_id, region_id}], else: []
    end)
    |> Enum.sort()
  end

  defp duplicate_dormant_anchors(state) do
    state
    |> Enum.flat_map(fn {region_id, region} ->
      Enum.map(dormant_anchors(region), &{&1, region_id})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.flat_map(fn {identity_id, regions} ->
      case Enum.uniq(regions) do
        [_one] -> []
        many -> [{identity_id, Enum.sort(many)}]
      end
    end)
    |> Enum.sort()
  end

  defp build_dormant_identity_locations(state) do
    state
    |> Enum.filter(fn {_region_id, region} -> region.resolution in [:coarse, :inert] end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce(%{}, fn {region_id, region}, acc ->
      Enum.reduce(dormant_anchors(region), acc, fn identity_id, locations ->
        Map.put(locations, identity_id, region_id)
      end)
    end)
  end

  defp dormant_anchors(%MultiResolutionRegion{resolution: resolution, summary: summary})
       when resolution in [:coarse, :inert] and is_map(summary),
       do: Map.get(summary, :identity_anchors, [])

  defp dormant_anchors(_region), do: []

  defp number(map, key, default \\ 0.0) do
    case Map.get(map, key, default) do
      value when is_number(value) -> value * 1.0
      _ -> default
    end
  end
end
