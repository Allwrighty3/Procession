defmodule Procession.Simulation.MultiResolutionRegion do
  @moduledoc """
  Loss-aware resolution transitions for a bounded world region.

  A live region contains explicit entities and resources. Compression produces a
  coarse causal summary that retains conserved stocks, bodily capacity, spatial
  commitments, and sparse social/history anchors. Refinement reconstructs one of
  many compatible live states; it does not claim to recover the original microstate.

  This module owns no processes and selects no outcomes for active entities.
  """

  defstruct id: nil,
            resolution: :live,
            tick: 0,
            bounds: {8, 8},
            entities: %{},
            resources: %{},
            social_relations: %{},
            causal_flags: MapSet.new(),
            summary: nil

  @type t :: %__MODULE__{}

  def new(opts) when is_list(opts) do
    %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      tick: Keyword.get(opts, :tick, 0),
      bounds: Keyword.get(opts, :bounds, {8, 8}),
      entities: normalize_entities(Keyword.get(opts, :entities, [])),
      resources: normalize_resources(Keyword.get(opts, :resources, [])),
      social_relations: normalize_relations(Keyword.get(opts, :social_relations, %{})),
      causal_flags: MapSet.new(Keyword.get(opts, :causal_flags, []))
    }
  end

  def compress(%__MODULE__{resolution: :live} = region, opts \\ []) do
    entities = Map.values(region.entities)
    resources = Map.values(region.resources)
    population = length(entities)
    held_stock = Enum.sum(Enum.map(entities, & &1.inventory))
    available_stock = Enum.sum(Enum.map(resources, & &1.quantity))
    consumed_stock = Enum.sum(Enum.map(entities, &Map.get(&1, :consumed, 0.0)))
    mean_energy = mean(entities, & &1.energy)
    mean_mobility = mean(entities, &Map.get(&1, :mobility, 1.0))
    {centroid, spread} = spatial_commitment(entities)
    relation_limit = Keyword.get(opts, :summary_relation_limit, 24)

    summary = %{
      region_id: region.id,
      tick: region.tick,
      bounds: region.bounds,
      population: population,
      available_stock: available_stock,
      held_stock: held_stock,
      consumed_stock: consumed_stock,
      total_stock: available_stock + held_stock + consumed_stock,
      mean_energy: mean_energy,
      mean_mobility: mean_mobility,
      centroid: centroid,
      spatial_spread: spread,
      relation_anchors: relation_anchors(region.social_relations, relation_limit),
      causal_flags: region.causal_flags,
      compression_version: 1
    }

    %{region | resolution: :coarse, entities: %{}, resources: %{}, social_relations: %{}, summary: summary}
  end

  def compress(%__MODULE__{resolution: resolution}) when resolution in [:coarse, :inert], do: raise(ArgumentError, "region is already compressed")

  def make_inert(%__MODULE__{resolution: :coarse} = region) do
    %{region | resolution: :inert}
  end

  def make_inert(%__MODULE__{}), do: raise(ArgumentError, "only coarse regions can become inert")

  def coarse_run(%__MODULE__{resolution: resolution, summary: summary} = region, ticks, opts \\ [])
      when resolution in [:coarse, :inert] and is_integer(ticks) and ticks >= 0 do
    demand = max(0.0, Keyword.get(opts, :per_entity_demand, 0.004))
    inflow = max(0.0, Keyword.get(opts, :external_inflow, 0.0))
    outflow = max(0.0, Keyword.get(opts, :external_outflow, 0.0))
    recovery = max(0.0, Keyword.get(opts, :energy_recovery_per_stock, 0.45))
    baseline_decay = max(0.0, Keyword.get(opts, :energy_decay, 0.0015))

    updated =
      Enum.reduce(1..max(ticks, 1), summary, fn _, acc ->
        if ticks == 0 do
          acc
        else
          requested = acc.population * demand
          consumed = min(acc.available_stock + inflow, requested)
          available = max(0.0, acc.available_stock + inflow - consumed - outflow)
          energy_delta = consumed * recovery / max(acc.population, 1) - baseline_decay

          acc
          |> Map.put(:available_stock, available)
          |> Map.update!(:consumed_stock, &(&1 + consumed))
          |> Map.update!(:total_stock, &(&1 + inflow - outflow))
          |> Map.update!(:mean_energy, &clamp(&1 + energy_delta, 0.0, 1.0))
          |> Map.update!(:tick, &(&1 + 1))
        end
      end)

    %{region | tick: updated.tick, summary: updated}
  end

  def coarse_run(%__MODULE__{}, _ticks, _opts), do: raise(ArgumentError, "only coarse or inert regions can advance coarsely")

  def refine(%__MODULE__{resolution: resolution, summary: summary} = region, seed, opts \\ [])
      when resolution in [:coarse, :inert] and is_integer(seed) do
    entity_prefix = Keyword.get(opts, :entity_prefix, to_string(region.id))
    resource_count = max(1, Keyword.get(opts, :resource_count, 1))
    positions = deterministic_positions(summary.population, summary.bounds, seed, summary.centroid)
    inventories = split_quantity(summary.held_stock, summary.population, seed + 17)
    consumed = split_quantity(summary.consumed_stock, summary.population, seed + 31)
    energies = distribute_mean(summary.mean_energy, summary.population, seed + 47)

    entities =
      1..summary.population
      |> Enum.map(fn index ->
        id = "#{entity_prefix}:#{index}"

        {id,
         %{
           id: id,
           position: Enum.at(positions, index - 1),
           energy: Enum.at(energies, index - 1),
           mobility: summary.mean_mobility,
           inventory: Enum.at(inventories, index - 1),
           consumed: Enum.at(consumed, index - 1)
         }}
      end)
      |> Map.new()

    resources =
      split_quantity(summary.available_stock, resource_count, seed + 61)
      |> Enum.with_index(1)
      |> Map.new(fn {quantity, index} ->
        id = "#{region.id}:resource:#{index}"
        position = Enum.at(deterministic_positions(resource_count, summary.bounds, seed + 73, summary.centroid), index - 1)
        {id, %{id: id, position: position, quantity: quantity, signal_strength: 1.0}}
      end)

    relations = restore_relation_anchors(summary.relation_anchors)

    %{
      region
      | resolution: :live,
        tick: summary.tick,
        bounds: summary.bounds,
        entities: entities,
        resources: resources,
        social_relations: relations,
        causal_flags: summary.causal_flags,
        summary: nil
    }
  end

  def refine(%__MODULE__{}, _seed, _opts), do: raise(ArgumentError, "only coarse or inert regions can be refined")

  def trace(%__MODULE__{} = region) do
    %{
      id: region.id,
      resolution: region.resolution,
      tick: region.tick,
      entity_count: map_size(region.entities),
      resource_count: map_size(region.resources),
      relation_count: map_size(region.social_relations),
      causal_flags: region.causal_flags,
      summary: region.summary
    }
  end

  def state_cost(%__MODULE__{resolution: :live} = region) do
    map_size(region.entities) * 8 + map_size(region.resources) * 5 + map_size(region.social_relations) * 7 + MapSet.size(region.causal_flags)
  end

  def state_cost(%__MODULE__{summary: summary}) when is_map(summary) do
    14 + length(summary.relation_anchors) * 7 + MapSet.size(summary.causal_flags)
  end

  defp normalize_entities(entities) do
    Map.new(entities, fn entity ->
      id = Map.fetch!(entity, :id)
      {id, %{id: id, position: Map.get(entity, :position, {0, 0}), energy: clamp(Map.get(entity, :energy, 0.75), 0.0, 1.0), mobility: clamp(Map.get(entity, :mobility, 1.0), 0.0, 1.0), inventory: max(0.0, Map.get(entity, :inventory, 0.0)), consumed: max(0.0, Map.get(entity, :consumed, 0.0))}}
    end)
  end

  defp normalize_resources(resources) do
    Map.new(resources, fn resource ->
      id = Map.fetch!(resource, :id)
      {id, %{id: id, position: Map.get(resource, :position, {0, 0}), quantity: max(0.0, Map.get(resource, :quantity, 0.0)), signal_strength: max(0.0, Map.get(resource, :signal_strength, 1.0))}}
    end)
  end

  defp normalize_relations(relations) when is_map(relations), do: relations
  defp normalize_relations(relations) when is_list(relations), do: Map.new(relations)

  defp relation_anchors(relations, limit) do
    relations
    |> Enum.sort_by(fn {key, relation} -> {-(Map.get(relation, :extreme_imprint, 0.0) + Map.get(relation, :persistence, 0.0) + Map.get(relation, :confidence, 0.0)), key} end)
    |> Enum.take(limit)
    |> Enum.map(fn {key, relation} -> {key, Map.take(relation, [:expectation, :confidence, :persistence, :extreme_imprint, :exposure, :last_tick])} end)
  end

  defp restore_relation_anchors(anchors), do: Map.new(anchors)

  defp spatial_commitment([]), do: {{0.0, 0.0}, 0.0}
  defp spatial_commitment(entities) do
    count = length(entities)
    x = Enum.sum(Enum.map(entities, fn %{position: {px, _}} -> px end)) / count
    y = Enum.sum(Enum.map(entities, fn %{position: {_, py}} -> py end)) / count
    spread = Enum.sum(Enum.map(entities, fn %{position: {px, py}} -> abs(px - x) + abs(py - y) end)) / count
    {{x, y}, spread}
  end

  defp deterministic_positions(count, _bounds, _seed, _centroid) when count <= 0, do: []
  defp deterministic_positions(count, {max_x, max_y}, seed, {cx, cy}) do
    Enum.map(1..count, fn index ->
      jitter_x = rem(:erlang.phash2({seed, index, :x}), max(max_x + 1, 1))
      jitter_y = rem(:erlang.phash2({seed, index, :y}), max(max_y + 1, 1))
      x = clamp(round(cx) + jitter_x - div(max_x, 2), 0, max_x)
      y = clamp(round(cy) + jitter_y - div(max_y, 2), 0, max_y)
      {x, y}
    end)
  end

  defp split_quantity(_quantity, count, _seed) when count <= 0, do: []
  defp split_quantity(quantity, count, seed) do
    weights = Enum.map(1..count, fn index -> 1.0 + :erlang.phash2({seed, index}, 1000) / 1000 end)
    total = Enum.sum(weights)
    raw = Enum.map(weights, &(quantity * &1 / total))
    correct_sum(raw, quantity)
  end

  defp distribute_mean(_mean, count, _seed) when count <= 0, do: []
  defp distribute_mean(mean, count, seed) do
    deviations = Enum.map(1..count, fn index -> (:erlang.phash2({seed, index}, 2001) - 1000) / 10_000 end)
    centered = mean(deviations, & &1)
    values = Enum.map(deviations, &clamp(mean + &1 - centered, 0.0, 1.0))
    correction = mean - mean(values, & &1)
    Enum.map(values, &clamp(&1 + correction, 0.0, 1.0))
  end

  defp correct_sum([], _target), do: []
  defp correct_sum(values, target) do
    difference = target - Enum.sum(values)
    List.update_at(values, -1, &(&1 + difference))
  end

  defp mean([], _fun), do: 0.0
  defp mean(values, fun), do: Enum.sum(Enum.map(values, fun)) / length(values)
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
