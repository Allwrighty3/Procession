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

    summary = Map.put(coarse.summary, :identity_anchors, identities)
    %{coarse | summary: summary}
  end

  @doc "Refines a compressed region and restores bounded identity anchors."
  def refine_region(%MultiResolutionRegion{} = region, seed, opts \\ []) do
    refined = MultiResolutionRegion.refine(region, seed, opts)
    anchors = Map.get(region.summary, :identity_anchors, [])
    generated = refined.entities |> Map.keys() |> Enum.sort()
    rename_pairs = Enum.zip(Enum.take(generated, length(anchors)), anchors)

    entities =
      Enum.reduce(rename_pairs, refined.entities, fn {generated_id, anchored_id}, acc ->
        entity = Map.fetch!(acc, generated_id)

        acc
        |> Map.delete(generated_id)
        |> Map.put(anchored_id, %{entity | id: anchored_id})
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

  def handle_call(:trace, _from, state) do
    trace = Map.new(state, fn {id, region} -> {id, MultiResolutionRegion.trace(region)} end)
    {:reply, trace, state}
  end

  def handle_call(:dormant_identity_locations, _from, state) do
    {:reply, build_dormant_identity_locations(state), state}
  end

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
end